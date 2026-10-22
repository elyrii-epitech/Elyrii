# Context inspection, correction and deletion

These authenticated APIs complete the stored-context lifecycle. They do not add a Flutter management UI or enable persistent-context prompt composition. Apply migration `0005_brainy_mystique.sql` with `bun run db:migrate` before deploying the server; `db:push` does not install the suppression triggers.

## API contract

Every endpoint is under `/context` and uses the existing bearer-token or signed-cookie authentication. Ownership always comes from the verified token. Request bodies cannot set an owner, source, model, status, expiry or retention policy. Responses use `Cache-Control: no-store`.

| Method and path | Input | Result |
| --- | --- | --- |
| `GET /facts` | Optional `limit` (1–100, default 25), `after` UUID cursor, `status` (`active`, `superseded`, `deleted`) | `{items, nextCursor}` |
| `GET /memories` | Same pagination/filter parameters | `{items, nextCursor}` |
| `PATCH /facts/:id` | `{ "value": <non-null JSON value> }` | Updated fact |
| `PATCH /memories/:id` | `{ "content": "corrected readable text" }` | Updated memory |
| `DELETE /facts/:id` | No body | 204 |
| `DELETE /memories/:id` | No body | 204 |
| `DELETE /all` | No body | 204; forget all current stored context |
| `DELETE /messages/:id` | No body | 204; physically delete an owned source message |
| `DELETE /conversations/:id` | URL-encoded conversation ID | 204; physically delete that user's conversation |

Lists use ascending ID keyset pagination. Reuse `nextCursor` as `after`; null means the end of the current scan. Concurrent changes can alter later pages; pages are not an export snapshot. Items include IDs, source message IDs, origin, status, validity and timestamps. Memory items also include retention, event time, expiry and content revision. Source text is available through the existing authenticated chat-history API, not copied into context-management responses. Expired facts/memories are excluded from these lists even before cleanup. Future-valid and inactive records can be inspected, but they are not eligible for retrieval.

Invalid input returns 400, unauthenticated requests return 401, and correction of a missing or foreign ID returns the same 404. Corrections to inactive/expired records return 409. Deletes return 204 for both nonexistent and foreign IDs and never modify another user's rows. Bodies are capped at 50 KB; corrected memory text is capped at 10,000 characters. Correction preserves the record's existing validity and retention window, and marks its origin `explicit`.

## What forgetting means

Forgetting retains chat text for the user's history, but permanently marks existing messages in the source conversation `context_suppressed`. Conversation-wide suppression is deliberately conservative: assistant paraphrases and later messages may repeat the forgotten assertion. Those existing messages no longer participate in extraction, rolling summaries, recent context or retrieval continuity. This also invalidates the conversation's cached summary and outstanding summary work. **Other existing context records are retained**, except interpretations derived from the same source message as the forgotten item; these are deleted together. Context management clients should explain this scope before presenting the operation.

A correction uses the same conservative conversation suppression to prevent the old assertion being reconstructed. The corrected record keeps its ID and provenance. Fact corrections retain a protected fact-key marker; automated extraction cannot overwrite that key, even from a new source. Users can correct it again through the API. Memory corrections increment the database-controlled content revision, remove old vectors, replace embedding jobs and schedule the new content when it is eligible. Late results cannot attach a vector for the previous revision.

`DELETE /all` suppresses all existing source messages, removes facts, memories, vectors and summaries, fences outstanding extraction/summary jobs, and preserves protected extraction keys. New messages can supply new context; retained old messages cannot seed a backfill. Suppression is monotonic: editing a retained message or writing `context_suppressed=false` cannot remove its marker. Suppression and deduplication markers contain IDs/keys rather than copies of private message text and remain until account deletion.

Direct stored-context deletes and soft deletes also protect their recorded source and extraction-key marker at the database layer. All public management writes are transactional and serialize on the authenticated owner. Job completion checks source suppression and generation/revision fences, so replay and backfill cannot undo a committed forget operation. There is no model-level guarantee of erasing independent assertions previously supplied through other sources; users can inspect and delete those records or use forget-all.

## Physical deletion

Message deletion removes the actual chat row and cascades its facts, memories, embeddings and extraction jobs. Existing summary-source triggers invalidate the whole affected summary and its in-flight generation for **any** changed/deleted source, not just the summary boundary. Conversation deletion applies this to all owned messages. Neither operation can delete another user's conversation with the same external conversation ID.

The existing account-deletion flow deletes the owner row; foreign-key cascades remove context, retained source suppression flags, extraction-key markers, summaries and per-user jobs. Model definitions and global backfill cursors contain no user text and remain. In-flight workers may finish computation, but cannot write results after the parent disappears. Management endpoints do not cache private responses or log request bodies, SQL errors, source text or provider output.

## Expiry and cleanup

Eligibility uses half-open intervals: `validFrom <= now < validUntil`, and `now < expiresAt`. Expired memories disappear from memory reads, vector retrieval and inspection immediately. Their source messages are also excluded from context tails and extraction; summaries for conversations containing expired sources are withheld until cleanup invalidates/rebuilds them. Normal chat history remains readable.

`startContextCleanup` runs an immediate bounded pass, then schedules the next pass after the previous one completes. It physically deletes memories whose expiry or validity has ended, protecting their retained sources and cascading their embedding cache/jobs. Each pass examines at most the configured number of memory candidates and rechecks eligibility under the owner lock. A failed pass is retried on the next interval; overlapping server instances and repeated passes are idempotent. Source suppression can touch multiple messages in the affected conversation. Facts with ended validity remain historical records but are excluded from reads; the cleanup worker physically purges memories.

| Variable | Default | Range |
| --- | --- | --- |
| `ENABLE_CONTEXT_CLEANUP` | off unless `true`; VM Compose defaults to `true` | boolean |
| `CONTEXT_CLEANUP_INTERVAL_MS` | 60000 | 1000–86400000 |
| `CONTEXT_CLEANUP_BATCH_SIZE` | 100 | 1–500 |

The worker runs independently of Kafka availability. Failures emit only a generic operation label; no private data appears in cleanup logs. Deployments outside VM Compose must enable it explicitly.

## Verification

Run `bash elyrii_server/scripts/test-context-db.sh`. The isolated PostgreSQL suite covers real authentication and cursor pagination, foreign-user operations, repeated deletion, retained-source suppression, new extractor versions, protected fact corrections, stale embedding results, non-boundary summary-source deletion, expiry at the exact boundary, concurrent cleanup, forget-all followed by new messages, and conversation/account cascades. Existing extraction, summary, embedding and retrieval regression suites run alongside these checks.
