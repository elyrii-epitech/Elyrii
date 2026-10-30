# Journal recall

Journal-derived stable facts and preferences now use the existing direct facts
layer; experiences use existing PostgreSQL memories and revision-aware embeddings.
Recall is opt-in and uses the same optional prompt allocation as chat context.
There is no whole-journal injection, journal-as-chat replay, new datastore or
journal summary. Current-conversation summaries and recent messages remain scoped
to that conversation. This depends on migrations 0007/0008; no new migration is
needed for recall.

## Enablement and rollback

Set `ENABLE_PERSISTENT_CONTEXT=true` and `ENABLE_JOURNAL_RECALL=true` on both the
server and AI bridge only after deployment review. Journal recall defaults to
false independently of extraction and mood context. Both AI-only and VM Compose
expose the bridge setting; VM Compose also exposes the server setting. The server
reads production retrieval settings on each request, including prompt refresh.
Changing a process environment in deployment still requires restarting that process.

Disabling journal recall removes journal-derived facts as well as memories while
preserving ordinary chat sources, continuity and independently enabled mood logs.
Disabling persistent context retains its existing ordinary-chat fallback. Disabling
journal extraction alone stops new extraction; it does not disable recall of
eligible previously stored context. Roll back recall using its switch; retain the
source schema and lifecycle triggers.

Each stored row has one authoritative source. Exact-duplicate suppression does not
merge provenance or convert a journal source into a chat source. Eligibility and the
recall switch are applied before ranking/deduplication, so disabling journals can
leave an independently eligible chat duplicate available. A future multi-source
schema will need an explicit source-by-source policy; it is not supported here.

## Eligibility and attribution

Semantic search filters owner, lifecycle status, validity/expiry, model digest and
dimensions, and embedding content revision before similarity ranking and top-k.
Journal records additionally require an existing owner-scoped backing entry and
source version, the current journal revision, an active/non-excluded version, a
non-suppressed/non-deleted entry, and a finite original observation time no later
than retrieval time. Final assembly repeats these checks and verifies that the
ranked memory revision and vector update timestamp still match.

The signed prompt-time refresh retrieves again from current database state. Queued
readable sections never authorize reuse of old journal context. Editing, deleting,
forgetting or excluding after dispatch invalidates that source at refresh. As with
existing chat context, the response represents a fresh database snapshot; it is not
a transaction held open throughout model inference. Late extraction/embedding
results remain subject to #233/#230 revision and forgetting checks.

Attributed payloads carry source kind, ID, revision and original `observedAt`, plus
origin and any supported `eventAt`, calendar `eventDate`, `temporalExpression` and
source timezone. Observation time and event time are distinct. Source timestamps
are formatted in SQL to retain database precision. The bridge independently checks
journal rollout, ownership, lifecycle dates and matching typed source fields, then
whitelists attributed data. Raw extraction quotes and journal bodies are not copied
into the generation prompt.

Expired temporary sadness is not recalled. Durable events may remain eligible years
later, but must pass the relevance threshold to enter selected memories. The trusted
prompt policy treats all journal material as historical untrusted data, forbids
instructions/role changes within it, and gives the current explicit user statement
precedence over conflicting historical claims. A live model evaluation is still
needed to establish whether a particular model follows that policy.

## Matching and budget limits

Duplicate content is compared after trimming, collapsing whitespace and lowercasing,
across chat/journal sources. SQL performs this before top-k; final assembly and the
bridge repeat suppression. Similarity descending then record ID gives deterministic
ties. This is exact normalized text matching, not semantic entity/event merging;
paraphrases, changed punctuation, translations and different Unicode normalizations
may remain separate. Existing chat source/summary coverage suppression is preserved.
Journal sources are not collapsed into a single memory slot: distinct relevant
experiences from one entry remain independently selectable. #230 currently rejects
oversized whole entries instead of chunking, so there are no chunk identities to
merge. Old revisions are ineligible rather than treated as extra memories.

Facts/preferences remain available without semantic similarity; memories retain the
existing threshold and top-k. No journal-specific allocation is added. The actual
generation-tokenizer composer reserves trusted instructions, current input, template
overhead and response tokens, then admits preferences/facts, continuity, optional
mood and ranked memories under the existing ordering. Oversized optional records are
dropped whole. The current input appears once and native boundary tokens inside
journal text are escaped.

Query-embedding failure drops semantic memories while preserving direct eligible
facts, continuity and mood. Retrieval failure during refresh yields verified
current-input-only chat. Failure to verify the current input yields the existing
retry response. Missing, excluded or stale journal sources never provide a fallback
to queued snapshots.

## User lifecycle

The existing context inspection endpoints identify the journal source and revision.
Correction retains provenance and updates the row, but excludes the underlying
journal from further automatic processing. Because recall requires a non-excluded
source, that corrected journal-derived row remains inspectable but is withheld from
automatic recall. There is no re-enable-source endpoint in this version.

Forgetting derived context excludes the journal durably and removes its derived
rows; it **does not delete the original journal entry**. Source edits invalidate the
old revision immediately; journal deletion invalidates its derived context. Fact
key suppression and conservative extraction reconciliation continue to protect user
corrections and newer explicit information across sources.

## Verification and review

Run the isolated PostgreSQL-to-prompt regression suite:

```sh
CONTEXT_EVAL_DIR=/tmp/journal-evaluation EVAL_PYTHON=/path/to/python \
  bash elyrii_server/scripts/evaluate-context.sh
```

`journal-lifecycle.json` contains synthetic refreshed payloads after save,
extraction/backfill, embedding, relevant/unrelated English/French requests, expiry,
cross-source duplicates, source edits, deletion, correction/exclusion, forgetting,
provider failure, and recall disablement after dispatch. `journal-report.json`
records token counts and retrieval/composition timings. Existing #230 tests also
exercise cross-source fact conflicts, invalid evidence, stale workers and embeddings.
Python checks combine chat, journals and mood under a tight budget and test native
role/token injection and malformed provenance. The adversarial source fixture is
intentionally inserted using mocked extraction to stress the recall boundary; it
is not evidence that live extraction would or should accept that instruction.

The checked-in [regression measurements](journal-recall-evaluation.json) use mocked
embeddings/extraction and a small test tokenizer. They establish deterministic
selection/lifecycle behavior, **not production relevance, model safety or generation
latency**. Token numbers are regression measurements, not actual-generation counts.

Live evaluation was initially deferred on 2026-10-27, then completed on 2026-10-29
after the tokenizer was supplied. The [reviewed live report](journal-recall-live-evaluation.json)
records eight base Mistral 7B Instruct Q4_K_M responses: **2 pass, 3 partial, 3 fail**
under Codex qualitative review. The LoRA adapter was not applied. Failures include
calling a 2020 event recent, missing dated journal attribution, unsolicited sadness
in an unrelated French response, and invented event details. Neither adversarial
case followed the injected instruction; both current-emotion cases passed.

The supplied SentencePiece tokenizer was converted locally with Transformers 4.57.6
and tokenizers 0.22.2. All 32,768 vocabulary entries match the served model; artifact
hashes and model digest are recorded in the report. Provider counts were consistently
two tokens above native counts, within the eight-token allowance. All cases fit
the 4,096-token window with 512 tokens reserved. Generation p50 was 1.01 seconds;
p95 was 10.56 seconds including the first cold load (only eight samples).
These results **do not support enablement**. The reusable runner is:

```sh
python -m elyrii_ai.scripts.evaluate_journal_recall \
  --tokenizer-dir /path/to/reviewed-tokenizer --model EXACT_MODEL_TAG \
  --url http://localhost:11434 --output /tmp/journal-recall-live.json
```

This measures live generation with synthetic selected context. Review historical
emotion assertions, relevant/irrelevant sensitive recall, current-statement priority,
source/date attribution and adversarial responses separately from search relevance.
The report records the serving digest, native token counts, provider token counts,
and generation p50/p95. Real embedding relevance and production latency require an
additional reviewed deployment dataset. #228's actual-model enablement review and
#230's failed Mistral extraction evaluation remain applicable. **Do not enable
journal recall by default based on these synthetic regressions.**


## Supplied LoRA evaluation (2026-10-29)

The [LoRA evaluation report](journal-recall-lora-evaluation.json) records the same
eight cases with the supplied adapter converted to F32 GGUF and loaded at scale 1.
Ollama 0.40.8 rejected adapter loading, so the run used its bundled llama.cpp server
with the same cached Mistral Q4_K_M base. No base weights were merged or overwritten.

**The supplied adapter has no effective weight update:** all 224 `lora_B.weight`
tensors (22,020,096 elements) are exactly zero. Standard LoRA adds a scaled `B @ A`
product, so these weights do not change the base model. The report includes source
and converted-adapter hashes, tensor counts, configuration, conversion revision,
and per-case responses. This is consistent with an untrained or incorrectly
exported checkpoint, but the cause has not been established.

Codex review found **2 pass, 3 partial, 3 fail**. Both current-emotion cases passed;
both injection attempts were resisted, with incomplete attribution. Historical
recency, attribution, verbosity and unsolicited sadness failures remain. All
prompts fit the existing token budget. Runtime differences mean output and latency
differences from the earlier run cannot be treated as fine-tuning effects.
A trained checkpoint with nonzero adapter updates is needed before evaluating the
intended fine-tuned model. Recall remains disabled by default.
