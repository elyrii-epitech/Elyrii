# Three-layer context retrieval

`ContextRetrievalService.retrieve(authenticatedUserId, request)` returns structured context for a chat request. It does not compose a prompt, change the Kafka chat payload, or alter the current WebSocket flow. The prompt integration step can call this service after persisting the input and before building the AI request.

```ts
import { ContextRetrievalService } from "../../modules/context/retrieval.service";

const retrieval = new ContextRetrievalService();
const context = await retrieval.retrieve(authenticatedUserId, {
    conversationId,
    query: message,
    currentMessageId: persisted.id,
});
// Pass message separately as the current input when composing a future prompt.
```

The owner comes from authenticated server identity, never request JSON. `currentMessageId` must be supplied when the current input is already persisted. Omit it only when retrieval precedes persistence. Conversation IDs are always scoped to the owner.

## Returned sections

- **`facts`**: all active, currently valid facts and preferences for the user, ordered by key and ID. No similarity threshold or semantic top-k applies. Each row retains its kind, origin, source message ID, validity and timestamps.
- **`continuity`**: the current conversation's summary and a bounded chronological tail of uncovered recent messages. The persisted current input and later messages are excluded. A summary that already covers the current input is omitted, and the recent tail is loaded from raw history instead. An unknown, deleted, wrong-owner or wrong-conversation current ID yields empty continuity rather than a broader fallback. `truncated` reports that older uncovered messages were omitted by the recent-message limit.
- **`memories`**: eligible past experiences with exact cosine similarity scores, immutable model IDs, readable content, content revision, source message IDs, origin, event time, validity, expiry and creation/update timestamps.
- **`semanticStatus`**: `ok` includes a successful search with no sufficiently relevant results; `unavailable` means query embedding or vector lookup failed. Facts and continuity are still loaded on semantic failure. A database failure that also prevents loading those sections propagates to the caller.

## Semantic search

Query encoding uses the same digest-pinned `embeddinggemma:300m`, raw-v1 input and normalized 768-dimensional vectors as [memory embeddings](memory-embeddings.md). The server calls the configured Ollama instance directly, verifies the artifact digest before and after embedding, rejects malformed/oversized responses and disables silent truncation. Query vectors are transient and are not stored. There is no unscoped or cross-model fallback.

Exact pgvector cosine search filters ownership, active status, validity, expiry, model identity, dimensions, registry enablement and matching content revision before ranking and limiting. A materialized CTE preserves that filtering boundary. The distance operation also has a `CASE` dimension/nonzero-norm guard, so optimizer predicate ordering cannot cause an unrelated mixed-dimension row to fail the request. No ANN index is added.

Normalized text duplicates (case and whitespace) and memories sharing source provenance are collapsed before top-k. Final assembly removes memories whose source is already represented by a returned fact, recent message, the current input or the selected conversation summary. It can therefore return fewer than top-k; it does not add lower-relevance replacements. This is deterministic overlap suppression, not a claim of general semantic paraphrase detection.

## Races and consistency

Slow embedding and ranking happen before final assembly. Ranked candidates carry only IDs, revision, vector update timestamp and score. Final assembly opens a fresh repeatable-read snapshot, reloads facts and continuity, and rechecks memory ownership, eligibility, model, revision and vector timestamp. Deletions, corrections, expiry or cache replacement committed before that snapshot cannot return stale ranked content. All returned sections describe that final snapshot; changes committed after it apply to the next retrieval. No external provider work occurs while the snapshot is open.

The lower-level repository is internal; callers should use the service, which validates requests, configuration, model identity and query vectors. Applications must not cache returned private context across requests without equivalent revalidation.

## Configuration

The selected model must already be registered and its eligible memories embedded using the #225 pipeline. The server needs the same `EMBEDDING_MODEL_DIGEST` and `EMBEDDING_AI_BASE_URL` as the worker. The VM Compose configuration passes the provider URL and these settings to the server:

| Variable | Default | Allowed range |
| --- | --- | --- |
| `CONTEXT_MIN_SIMILARITY` | `0.65` | -1 to 1 |
| `CONTEXT_TOP_K` | `5` | 1–50 |
| `CONTEXT_RECENT_LIMIT` | `12` | 1–200 |
| `CONTEXT_EMBEDDING_TIMEOUT_MS` | `3000` | 1–30000 |

The deadline covers the complete provider operation, including digest checks, and aborts the HTTP requests. Input limits are 10,000 characters/40 KB UTF-8 and the response cap is 256 KB. Missing model configuration or provider failures degrade semantic retrieval. Invalid request/configuration values are rejected. The default relevance threshold is an initial policy setting, not a calibrated quality guarantee.

## Validation

Run `bash elyrii_server/scripts/test-context-db.sh` for the isolated PostgreSQL/pgvector suite, including multi-user/conversation isolation, unrelated preferences, older relevant experiences, expired emotions, status/validity exclusion, mixed dimensions, summary/current-input overlap, deduplication, provider timeout and deletion/correction races. Query-provider contract tests are in `modules/context/query-embedding.test.ts` and run as part of that suite.

Recall fixtures use controlled unit vectors to verify retrieval logic deterministically. They do not measure live model relevance or multilingual quality; those require a separate application evaluation. There is no new migration for this step.
