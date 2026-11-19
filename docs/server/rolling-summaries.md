# Rolling conversation summaries

Issue #224 adds asynchronous conversation continuity without changing the response
prompt or retrieving semantic memories. A versioned worker combines the prior
summary with a contiguous prefix of newly covered messages. The server commits
the text and `through_message_id` together with task completion.

## Deployment and tokenizer configuration

Run `bun run db:migrate` before deploying the server. Migration
`0003_rolling_summaries` creates one durable task per user/conversation, backfills
existing conversations, and installs source-change triggers. `db:push` cannot
install these triggers. Database writes schedule work transactionally even when
the dispatcher is disabled.

Summary processing is opt-in because an exact generation-model tokenizer is
required. Configure the server with `ENABLE_SUMMARIES=true` and enable its normal
Kafka consumers. Set `SUMMARY_AI_MODEL` to the exact Ollama model tag used by the
summary worker. The fallback is `AI_MODEL`, then `mistral`.

Install `elyrii_ai/requirements-bridge.txt`, then run `python summary_worker.py`
from `elyrii_ai` with these environment variables:

| Setting | Purpose |
| --- | --- |
| `KAFKA_BROKER` | Kafka broker, as for extraction |
| `SUMMARY_AI_BASE_URL` | Ollama URL; falls back to `AI_BASE_URL` |
| `SUMMARY_AI_MODEL` | Same model tag configured on the server |
| `SUMMARY_TOKENIZER_PATH` | Local `tokenizer.json` matching that model's tokenizer |

Both compose files provide a `summary-worker` under the `summaries` profile.
Set `SUMMARY_TOKENIZER_DIR` to a directory containing the matching
`tokenizer.json`; it is mounted read-only at `/tokenizer`. Enable the profile and
server flag together, for example:

```sh
ENABLE_SUMMARIES=true SUMMARY_TOKENIZER_DIR=/absolute/path/to/model-tokenizer \
  docker compose -f docker-compose-vm.yml --profile summaries up -d --build
```

The VM compose model tag is `OLLAMA_MODEL_NAME` (default `elyrii-lora`) for both
server and worker. For a LoRA/quantized derivative, supply the unchanged base
model tokenizer unless that derivative actually changes its vocabulary. This
mapping is an operator responsibility: the worker checks the configured model tag
against the job, but cannot prove that an arbitrary tokenizer file belongs to the
remote model. A missing/invalid tokenizer fails startup. No tokenizer is downloaded
at runtime, and there is no heuristic token-count fallback.

## Budgets and scheduling

The server freezes this policy in each dispatched job:

| Server setting | Default | Meaning |
| --- | --- | --- |
| `SUMMARY_MESSAGE_THRESHOLD` | 24 | Minimum number of older uncovered messages |
| `SUMMARY_TOKEN_THRESHOLD` | 2000 | Alternative threshold: sum of those messages' content tokens |
| `SUMMARY_KEEP_RECENT` | 8 | Latest messages kept outside summary coverage |
| `SUMMARY_INPUT_TOKENS` | 3000 | Token budget for the complete raw generation prompt |
| `SUMMARY_OUTPUT_TOKENS` | 512 | Token budget for the stored summary |

The worker generates when either threshold is met. Below both thresholds it
returns `skipped`, which leaves the summary and coverage unchanged until new
messages arrive. No inference job is sent when the history is empty or contains
only the retained recent messages.

Each snapshot contains at most 64 older messages and a bounded byte payload. The
worker counts tokens using `tokenizers.Tokenizer` loaded from the configured file,
with padding/truncation disabled. It chooses the longest **contiguous** prefix that
fits the input budget, including the prior summary, instructions, metadata and
special tokens. A single oversized first source fails with `input_too_large`;
it is never skipped or silently truncated to reach a later message. Likewise,
oversized/unsupported server inputs are recorded as terminal `invalid_input`.

Generation uses Ollama `/api/generate` with `raw: true`, an explicit versioned
summary prompt, temperature zero, and `num_predict` equal to the output budget.
The returned summary is independently counted with the same tokenizer. Empty,
over-budget, malformed, oversized or token-truncated responses are rejected.
`num_ctx` reserves input + output + 32 tokens; configure limits that the selected
generation model can support. Requests have a 30-second deadline and a 100 KB
response limit. The result reports the actual stored summary token count, which
the server verifies against the saved job budget.

## Coverage, concurrency and invalidation

All message ordering uses `(created_at, id)` ascending; equal timestamps therefore
have deterministic coverage. The task records ordered source IDs, a snapshot end,
an opaque summary revision, and a separate history version for pagination.
Plain later appends can coexist with an in-flight job. A backdated insert at or
before the stored/job boundary invalidates it so a message cannot fall behind
the boundary unnoticed.

Each result must match the task's user, conversation, job ID, model, revision and
attempt. Only a boundary in the original contiguous snapshot is accepted. The
server rechecks that prefix before writing. Partial-prefix completions leave the
remaining suffix for the next job. Completion updates the revision and clears
the active job in the same transaction as the summary upsert. Replayed,
overlapping, expired-attempt and pre-invalidation results cannot move coverage
backward or double-cover messages. Explicit `ContextRepository.putSummary` writes
also fence jobs and reject boundary regression.

Database triggers invalidate and delete a conversation's summary whenever **any**
source message in that conversation is edited or deleted. This deliberately
includes uncovered messages: a conservative rebuild avoids needing a large
historical coverage table. It handles earlier covered sources, not merely the
boundary foreign key, as well as moves between conversations/users. The next
job rebuilds from surviving messages with no prior summary. Existing summary
reads return null immediately after the mutation commits. No stale summary is
served during rebuilding or inference failure; raw surviving history remains.

Deleting a summary fences pending work. `ContextRepository.forgetAll()` fences
summary jobs even if no summary has been saved yet. User deletion cascades tasks.
Repository result writes use a user lock followed by the conversation task lock;
database transaction failures do not commit offsets and are replayed.

## Reading continuity

`SummaryRepository.continuity(userId, conversationId, limit, cursor?)` reads the
summary and uncovered messages in a single repeatable-read snapshot. The tail
starts strictly after the stored boundary, remains scoped to the user/conversation,
and is ordered ascending. It returns `summary`, `messages`, `revision`,
`historyVersion`, and `nextCursor` (null at the end).

The default page size is 200, capped at 500. Use `nextCursor` to read a longer tail.
If either history or summary changes between pages, the cursor is rejected and
the caller must restart; late inserts cannot silently disappear behind a cursor.
Consumers must not concatenate overlapping pages from different versions. Final
prompt assembly and any smaller final-context budget are intentionally separate.

## Delivery and failures

The topics are `elyrii.context.summary.jobs.v1` and
`elyrii.context.summary.results.v1`, keyed by user ID, with a separate consumer
group and worker from chat/extraction. Jobs/results carry version, job ID, user,
conversation, revision, attempt, and model. Jobs additionally contain policy,
timezone, the prior summary/boundary and speaker-labelled messages. Results are
`success` (summary, boundary and token count), `skipped`, or `failure` (a fixed
error code). Restrict topic producers to the trusted server/worker.

The dispatcher reuses the extraction delivery loop. Leases are committed before
publishing; acknowledgement loss is safe. The worker commits each input offset
only after publishing its result. Server result offsets are committed only after
database reconciliation. Publish/model failures use exponential backoff; abandoned
leases retry after 120 seconds plus backoff, with at most five attempts. Terminal
failures retain the previous valid summary and uncovered messages.

Inspect `conversation_summary_tasks.status`, `last_error`, `attempts` and
`next_attempt_at` for operations. Correct model/tokenizer/input configuration before
retrying terminal tasks. A source edit automatically schedules a rebuild. There
is no public administrative retry endpoint in this issue; do not manipulate task
revision/coverage fields to force a stale result through.

## Summary quality and verification

`elyrii_ai/prompt/summary/v1.txt` treats messages and previous summaries as
untrusted data, preserves speaker attribution, uncertainty, temporal reference,
negation and corrections, and forbids inventing user facts. Summaries remain
model-generated descriptions of a conversation, not verified personal facts.
They must remain untrusted context in future prompt assembly.

Run:

```sh
bash elyrii_server/scripts/test-context-db.sh
python -m unittest discover -s elyrii_ai/test -p 'test_*.py'
```

PostgreSQL tests cover long histories, equal timestamps, partial prefixes,
concurrent/repeated jobs, isolation, earlier-source edits/deletions, backdated
inserts, retries, inference failure, transactional rollback and pagination.
AI tests use mocked inference and an actual local test tokenizer to verify exact
token limits, attribution in the input, thresholds and transport failures.

Before enabling a production model, evaluate at least: a 100-turn conversation
across several summary updates; an assistant suggestion the user rejects; a user
saying they *might* have an exam tomorrow near a timezone date boundary; quoted
third-party speech; a corrected graduation date; temporary sadness; and embedded
instructions asking the summarizer to fabricate a fact. Compare the summary with
the covered messages for attribution, uncertainty and continuity. Record the model
tag/digest, tokenizer artifact and budgets. Mocked tests do not establish semantic
accuracy, and no live-model evaluation is claimed here.
