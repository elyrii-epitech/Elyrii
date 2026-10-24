# Journal extraction (#230)

The journal worker extracts evidence-backed context into the existing facts and
memories tables. It does not select context for replies (#231), generate journal
summaries, inspect media, or write to the mood tracker. It depends on the
[source foundation](journal-source-foundation.md) and migration 0008.

## Contracts and eligibility

Kafka topics are `elyrii.context.journal.jobs.v1` and
`elyrii.context.journal.results.v1`. Version 2 envelopes identify the owner, source
ID/revision, source event, forgetting generation, extractor `journal-v1`, job and
attempt. There is no synthetic conversation. Title, body and optional mood are
attributed untrusted evidence. The worker receives the original creation time and
an owner timezone snapshot; missing timezone stays unknown.

The model proposes at most eight candidates. Both server and worker enforce strict
schemas, exact evidence quotes, supported temporal expressions and category/retention
consistency. The server rechecks evidence against the current owner-scoped revision.
Only explicit, certain, affirmative assertions attributed to the author are eligible.
Uncertain/inferred, quoted, third-party, hypothetical and negated proposals are
withheld rather than stripped of qualifiers and promoted. The prompt also instructs
the model to omit these cases. Exact quotation alone does not establish entailment:
model evaluation must check attribution and meaning as well as syntactic fidelity.

Stable facts/preferences retain their category. Temporary emotions and minor events
are short-term memories; graduation/bereavement are durable life-event memories.
Mood evidence can only be a temporary emotional observation. Each inserted row keeps
its source reference, origin and evidence metadata: quote/field, certainty, category,
temporal expression, resolved calendar date, original reference time, timezone and
extractor version. Manual correction clears the extraction evidence because it no
longer supports the corrected assertion; source lineage and suppression remain.

Supported relative dates are today/yesterday/tomorrow and aujourd'hui/aujourd’hui/
hier/demain. The server resolves them against the original local calendar day,
including DST boundaries, and stores day precision as `eventDate`. Valid ISO
calendar dates also retain day precision. Other expressions, including ambiguous
weekdays, retain their exact words with an unknown resolved date. No midnight is
invented. `eventAt` requires an explicit offset timestamp in the evidence.
Short-term expiry still follows #233's original-source/event-instant policy; edits,
processing, retry and import do not refresh it. Historical durable events do not
establish a present emotional state. A known calendar date also caps short-term
freshness using its latest possible end across civil timezones (next day at 12:00
UTC), plus the retention window. This conservative upper bound does not populate
`eventAt`; it prevents newly imported, explicitly old emotions from becoming fresh
observations even when the import's creation time is recent.

## Whole-entry limits

The compact UTF-8 JSON input must be at most **24,000 bytes**, including metadata;
title/body each allow at most 24,000 characters, mood 1,000. A quote is at most 4,000
characters and the output at most eight proposals. The entire entry is sent or the
job fails with `invalid_input`. The worker explicitly requests a 32,768-token
context window and reserves 4,096 output tokens plus template overhead using a
conservative UTF-8 byte bound. No truncation, chunks, overlap or partial publication
are used. A valid event near the end of a supported entry is included. Duplicate
proposals are deduplicated; any invalid proposal or incomplete model response fails
the complete result. Classification limits mean this is selective extraction, not
an exhaustive inventory of every event in the journal.

## Queue, retries and atomicity

Journal saves commit #233's durable events without contacting Kafka or the model.
The independently reconnecting server service converts eligible create/update events
into unique `(event_id, extractor_version)` jobs. Event identity supplies owner,
source and revision. It snapshots timezone and stores no journal text in the queue.
Claims commit a lease before publication. Publishing/inference failure or an abandoned
lease retries with bounded exponential backoff, at most five attempts. Status and
bounded error codes are inspectable in `journal_extraction_jobs`. Malformed results
cannot safely identify a job; their leases expire and eventually exhaust attempts.

Reconciliation locks the owner, checks the job attempt, event, source revision,
exclusion and forgetting generation, then atomically commits context, evidence,
event completion and job completion. Duplicate delivery cannot duplicate records.
Any invalid fragment or conflicting same-key proposal rejects the complete result.
Database errors roll back and leave the Kafka result unacknowledged for replay.
Source edits/deletion, correction, exclusion and forgetting fence outstanding work.
Journal proposals never replace an active fact or a suppressed key, including newer
chat information and manual corrections. Unrelated memories are not guessed to be
corrections. Eligible memories use the existing embedding trigger/worker and revision
checks. Facts remain directly stored; journal recall remains gated until #231.

## Rollout and backfill

Apply migration 0008 after 0007 before deploying these writers. Keep the schema on
application rollback. The new worker is disabled by default. To enable new events:

- Set server `JOURNAL_EXTRACTION_ENABLED=true` and an explicit
  `JOURNAL_EXTRACTION_START_AT` ISO timestamp with offset. Events older than that
  timestamp are not automatically queued. Keep this cutoff fixed across restarts.
- Enable the normal Kafka consumers (`ENABLE_KAFKA_CONSUMERS=true`, or the existing
  development/production default).
- Start the AI compose `journal-extraction` profile, with
  `JOURNAL_EXTRACTION_ENABLED=true`, `JOURNAL_EXTRACTION_AI_BASE_URL` and
  `JOURNAL_EXTRACTION_AI_MODEL` configured. Model timeout is 20 seconds by default.
- Configure the existing embedding worker separately for searchable memory vectors.

No full-history backfill runs on deployment. An operator can explicitly enqueue one
owner-scoped page from `elyrii_server`:

```sh
JOURNAL_BACKFILL_ENABLED=true bun scripts/journal-backfill.ts USER_UUID
JOURNAL_BACKFILL_ENABLED=true bun scripts/journal-backfill.ts USER_UUID CURSOR_UUID 20
```

Each invocation scans/enqueues at most 100 eligible unqueued events and emits a
cursor/count. Persist the cursor and repeat until `scanned` is zero. Repeating a page
is safe. This path uses the same revision, freshness, exclusion and generation checks;
it cannot reset completed/failed jobs or unsuppress a source. New events are handled
by the live service. Worker processing still requires the explicit rollout switch.

Example inspection (no content selected):

```sql
SELECT j.status, j.last_error, count(*)
FROM journal_extraction_jobs j GROUP BY j.status, j.last_error;
```

Server completion and worker telemetry report counts, statuses and durations without
journal text, evidence, candidate content or user IDs. Error codes include
`invalid_input`, `invalid_candidates`, `publish_failed`, `inference_failed` and
`attempts_exhausted`. Retained evidence is private context data and is removed through
the existing forgetting/source/account cascades.

## Validation and model evaluation

Run `bash elyrii_server/scripts/test-context-db.sh`, the TypeScript check, and
`python -m unittest discover -s elyrii_ai/test`. Synthetic English/French fixtures
cover preference, sadness, minor events, graduation, bereavement, quotation,
third-party claims, negation, uncertainty and empty output. Deterministic tests cover
contracts, calendar dates, end-of-entry evidence, whole-entry rejection, duplicate
results, partial-invalid rollback, retries, generation/revision fencing, correction,
forgetting, embeddings and existing chat compatibility. Mocked outputs do **not**
establish live model quality.

Run the separate live evaluation against an available Ollama model:

```sh
python -m elyrii_ai.scripts.evaluate_journal_extraction \
  --url http://localhost:11434 --model MODEL_NAME \
  --output /tmp/journal-extraction-evaluation.json
```

The report records the model digest, fixture outputs, validated exact-quote fidelity,
classification/temporal errors, failures and latency. Review each output for semantic
support, attribution, polarity and uncertainty; exact substring validation cannot
replace that review. Extraction failures remain separate from valid empty outputs.
The script verifies that the model digest has not changed during the run.

### Mistral 7B Instruct evaluation (2026-10-22)

The [reviewed live report](journal-extraction-evaluation-mistral.json) uses
`mistral:7b-instruct`, digest
`6577803aa9a036369e481d648a2baebb381ebc6e897f2bb9a766a2aa7bfbc1cf`,
on the 20 synthetic English/French fixtures. No application database was used.
The temporary local Ollama endpoint was port 11435 with model storage on the
workspace disk, because the original service's root-disk download ran out of space.

| Measure | Result |
| --- | --- |
| Structurally validated outputs | 4/20 |
| Rejected outputs | 16/20 |
| Semantically correct end-to-end cases | 0/20 |
| Exact raw evidence quotes | 19/20 |
| Classification/kind errors across all raw outputs | 20/20 |
| Temporal mismatches across all raw outputs | 9/20 |
| Median / maximum latency | 1.149 s / 3.544 s |

All four structurally validated outputs had policy errors: English/French exams
became stable facts without dates, an English quotation was attributed to the
author, and a French negative preference bypassed the omission policy (its polarity
was preserved; it was not converted into liking coffee). Most rejected outputs used
`kind=fact` even for preferences and memories, and several invented date expressions.
Both empty-output fixtures failed. Exact evidence matching does not establish correct
attribution or classification; these accepted errors expose that remaining gap.

**Rollout gate failed. Keep extraction disabled.** These are results for this
model/prompt combination, not a claim about all Mistral configurations. Improve and
re-evaluate the model adapter/prompt or fine-tuned model before deployment. No
semantic failure was repaired or silently accepted by the evaluator.

The [initial baseline](journal-extraction-evaluation-mistral-baseline.json) used
Ollama's automatic 4,096-token context: 3 validated/17 rejected, no end-to-end correct
cases, and a 29.786-second cold-start maximum. Inspection of that configuration led
to the explicit context-budget fix; the final report uses 32,768 tokens. The
evaluator allows 60 seconds per case, while the production worker defaults to 20;
cold starts can therefore require a retry or prewarming. Deterministic regression
tests still pass and are separate from these failed live quality checks.
