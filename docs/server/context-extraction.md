# Asynchronous context extraction

Issue #223 connects persisted user messages to the candidate extractor from #222.
It does not add retrieval, change response prompts, or delay replies while waiting
for extraction. The chat path retains its persisted source ID and request ID.
The server's existing Kafka consumer enablement also starts the extraction outbox
and result consumer, with independent Kafka clients and connection retries.

## Deployment

Run `bun run db:migrate` in `elyrii_server` before starting the updated server.
Migration `0002_extraction_outbox` adds jobs, reconciliation high-water marks, a
user context generation, and forgetting triggers. Use the migration runner rather
than `db:push`: the triggers are SQL migration objects, not Drizzle table fields.

Run the independent worker with:

```sh
cd elyrii_ai
pip install -r requirements-bridge.txt
python extraction_worker.py
```

Both the VM compose file and AI compose file include a `context-extractor` service
using the bridge image with this command. Set `KAFKA_BROKER`, `AI_BASE_URL`, and
`AI_MODEL` as for the response bridge. `EXTRACTION_AI_BASE_URL` and
`EXTRACTION_AI_MODEL` can point extraction at a dedicated inference service.
Separate workers remove application-level blocking; sharing the same model server
still shares its compute capacity. Extraction Kafka/model outages do not gate the
chat clients, although ordinary replies still depend on their own Kafka/model path.

## Wire contracts

The server schemas live in `modules/context/extraction.contracts.ts`. The AI worker
validates the job envelope independently and invokes the strict #222 extractor.
Kafka topics are `elyrii.context.extraction.jobs.v1` and
`elyrii.context.extraction.results.v1`, keyed by user ID. Restrict topic write access
to the server and AI worker: source checks do not authenticate arbitrary publishers.

Both envelopes carry `version: 1`, `jobId`, `requestId`, `userId`, `conversationId`,
`sourceMessageId`, `extractorVersion: "v1"`, and `attempt` (1–5). Jobs additionally
carry `input` with the persisted user source (`id`, `role`, `content`, `messageAt`),
bounded prior user-message `context`, and the user's stored timezone (UTC fallback).
Jobs do not expose their database sequence or forgetting generation to the model.

Success results add `status: "success"` and `output`, the #222 result with
`promptVersion: "v1"` and up to eight proposals. Failure results add
`status: "failure"` and `error: "inference_failed" | "invalid_input"`. Results
never echo the full input or private exception text. The model controls only the
candidate output; the worker copies correlation fields from the validated job.

## Delivery and recovery

User-message insertion and outbox insertion share one database transaction and a
user-row lock. Assistant messages create no jobs. Failure in either insert rolls
back both. Oversized/unsupported source input is still saved for ordinary chat,
with a terminal `invalid_input` job instead of silently truncating its evidence.

The dispatcher polls each second in batches of at most 20. It claims due jobs with
`FOR UPDATE SKIP LOCKED`, increments the attempt, and commits an `awaiting` lease
before publishing. A lost acknowledgement or process crash may duplicate delivery;
it cannot lose the durable job. A result deadline of 120 seconds plus exponential
backoff recovers lost jobs/results. Explicit publish/model failures back off 5,
10, 20, 40, then 80 seconds, with at most five attempts. The general backoff helper
caps at five minutes. Unknown/invalid envelopes eventually exhaust the same bound.

The AI worker commits only the processed Kafka record's offset, after the result
publish succeeds. Failed publishes reconnect and replay. The server commits the
result offset only after the reconciliation transaction returns; database errors
escape the handler and trigger replay. A crash after database commit is safe
because the completed job cannot apply again. Late attempts and duplicate failure
results cannot change completed work or continually extend retry deadlines.

`context_extraction_jobs` records `pending`, `awaiting`, `retry`, `completed`,
`failed`, or `discarded`, attempt count, next attempt time, and a bounded error code.
Inspect failures without reading chat content:

```sql
SELECT status, last_error, count(*)
FROM context_extraction_jobs
GROUP BY status, last_error;
```

Pending/retry/awaiting jobs recover automatically. Failed jobs are terminal and
need operator investigation; no automatic infinite retries or public replay API
is provided. Never reset completed/discarded jobs, high-water marks or generation
values to force replay: these fields protect idempotency and forgotten data.
Keep completion records and high-water marks while their user/source remains;
do not purge them without designing equivalent durable tombstones. User deletion
cascades jobs and high-water marks; source deletion cascades its jobs.

## Storage decisions and ordering

Result application locks the owning user before the job. It checks every envelope
identity field against the stored job and revalidates the still-existing user
source and conversation. Evidence and temporal phrases must quote that source;
non-null event instants must occur in evidence. Extra fields, model-proposed expiry
or validity, incompatible classification, and mismatched source IDs are rejected.
The whole proposal batch is validated before any writes.

Only certain proposals are persisted: the current storage DTO cannot represent
the certainty of tentative statements without losing that metadata. The server
computes short-term expiry from `ContextPolicy` (48 hours by default, with existing
configured bounds). Identical facts are deduplicated by key and canonical JSON
value. Identical memories are deduplicated by readable content, retention and event
instant; repeating an existing memory does not extend its expiry.

User-locked outbox sequence is the deterministic precedence for automated fact
corrections, including sources saved at the same timestamp. Per-key high-water
marks prevent older results from replacing a newer value even when messages arrive
out of order. A changed fact supersedes the old row and inserts a new active row
within the same transaction. Completion and deduplication marks commit atomically
with every candidate write; an intermediate failure rolls everything back.

Distinct memory text is not automatically assumed to correct another memory: #222
does not supply an authoritative target ID. Explicit memory corrections continue
through `ContextRepository.correctMemory`, which preserves the superseded record,
deletes its embeddings, and now fences previously queued extraction. Fact
corrections through `replaceFact` also fence pending work. No semantic matching or
retrieval is introduced to guess correction targets.

## Forgetting

Deleting a fact/memory, or transitioning it to `deleted`, increments the user's
context generation via database triggers. `ContextRepository.forgetAll()` also
increments it explicitly so forgetting works even while all context is still
pending. Claims/results from an earlier generation are discarded. New user
statements snapshot the new generation and can introduce fresh context.

This barrier deliberately discards *all* older pending extraction for the user,
including unrelated candidates, rather than risking recreation of forgotten data.
Repository corrections/deletions take the same user lock as result application.
Direct concurrent SQL deletions can encounter ordinary PostgreSQL deadlock errors;
callers must retry the transaction. Failed transactions cannot partially revive
context. Deleting a source/user removes its jobs through foreign keys, and late
results for absent jobs are discarded without recreating them.

## Verification

```sh
# From the repository root; PostgreSQL runs in a disposable pgvector container.
bash elyrii_server/scripts/test-context-db.sh
bun test elyrii_server/modules/context
python -m unittest discover -s elyrii_ai/test -p 'test_*.py'
```

Database tests exercise atomic persistence, publish failure, abandoned leases,
bounded model failure, replay, competing dispatchers, concurrent/out-of-order
corrections, duplicate proposals, partial-write rollback, ownership, retention,
source/user deletion, forgetting and embedding invalidation. Server contract tests
reuse all #222 fixtures. Worker tests mock inference and publishing, including
publish failure and valid empty results. These do not claim real-model extraction
accuracy; the model-backed evaluation procedure remains in the AI extraction docs.
