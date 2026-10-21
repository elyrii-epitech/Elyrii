# Versioned memory embeddings

Embeddings are a rebuildable cache of readable `user_memories.content`. They are generated asynchronously and do not change memories, conversation history, summaries, or chat prompts. This foundation does not yet perform retrieval or inject memory into chat.

## Model and encoding contract

The selected provider is self-hosted Ollama, serving **`embeddinggemma:300m`**, with **768 dimensions**, cosine distance, and explicit unit normalization. The [Ollama model page](https://ollama.com/library/embeddinggemma:300m) lists a 622 MB BF16 artifact, a 2,048-token context, support for more than 100 languages, and Ollama 0.11.10 or later. The [Google model card](https://ai.google.dev/gemma/docs/embeddinggemma/model_card) describes its multilingual embedding architecture. English and French are intended application languages; retrieval quality in either language still requires application-specific evaluation.

`raw-v1` sends the exact readable memory content without a task prefix, trimming, truncation, or summarization. Future query embeddings must use the same artifact, preprocessing, dimensions and normalization. Changing any of those requires a new model version. The [Ollama embedding API](https://docs.ollama.com/api/embed) is called with `dimensions: 768`, `truncate: false`, and `options.num_ctx: 2048`.

The immutable identity is `embeddinggemma-300m@sha256:<full-64-character-digest>:raw-v1:768`. `EMBEDDING_MODEL_DIGEST` must contain the lowercase 64-character digest, without `sha256:`. A mutable tag alone is insufficient. The worker checks `/api/tags` against the configured digest before and after each request. Do not pull or repoint the model tag on an active provider instance; deploy different artifacts on separate provider instances when keeping versions running together. Registry metadata cannot be edited in place.

## Deployment

1. Apply migrations with `bun run db:migrate` from `elyrii_server`, using the normal `DB_*` settings. Migration `0004_memory_embeddings_jobs.sql` adds revision guards, durable jobs, model registration and scan progress. It clears existing embedding rows whose content revision cannot be proven; readable memories remain intact. **Use migrations, not `db:push`**, because the SQL triggers are required.
2. Pull `embeddinggemma:300m` into the intended Ollama instance and obtain its full digest from `GET /api/tags`. Provisioning the model is an explicit operator step; the worker does not download models.
3. Set the same `EMBEDDING_MODEL_DIGEST` on server and worker. Set `ENABLE_EMBEDDINGS=true` on the server. Set `EMBEDDING_AI_BASE_URL` if the worker should use a different Ollama instance.
4. Start the `embeddings` Compose profile. The VM deployment uses `docker compose -f docker-compose-vm.yml --profile embeddings up -d --build`; the AI-only Compose file also offers this profile. Existing database, Kafka and Ollama services must be available.

Registration creates a durable scan for the selected version and resumes it on restart. New and changed memories are queued by database triggers, including writes concurrent with registration. Jobs and results use `elyrii.context.embeddings.jobs.v1` and `elyrii.context.embeddings.results.v1`. Each artifact has separate consumer groups so simultaneous versions do not consume each other's work. Startup configuration/registration failures are logged; correct the configuration and restart the server.

## Bounds, retries and eligibility

The adapter accepts nonblank input up to 10,000 characters and 40 KB UTF-8. It enforces a 30-second total deadline (including digest checks), a 256 KB response cap, one vector of exactly 768 finite numeric elements, and a nonzero finite norm. Oversized model input is rejected rather than silently truncated. Jobs are limited to 64 KB at the worker and results to 100 KB at the server. Provider errors are sanitized; memory text and provider response bodies are not logged.

Jobs contain the memory ID, owner, content revision, model identity, generation ID and attempt. Dispatch and completion both recheck eligibility and ownership. Only active memories whose validity has started and whose validity/retention has not ended can produce usable vectors. Future-valid memories wait until their start time. Content or owner changes increment a database-controlled revision, invalidate the cache and replace queued work. Eligibility changes invalidate derived work too. Deleting a memory or user cascades to its vectors and jobs. Completion locks the parent before the job, so a racing deletion cannot recreate an orphan vector.

Provider/publication failures retry with bounded backoff, up to five attempts. A dispatch lease lasts 120 seconds plus backoff; abandoned leases are retried. Invalid input and artifact mismatch fail immediately. Generation, revision and attempt checks reject late results; duplicate deliveries are harmless. Vector insertion and job completion commit atomically. Workers publish results before committing Kafka offsets.

Time-based expiry is enforced on reads and completion immediately, even before cleanup. The publisher also removes expired/ineligible derived vectors in bounded batches. Readable-memory retention remains the responsibility of the existing retention process.

## Backfill, rebuild and recovery

Run from `elyrii_server` with the desired digest and normal database environment:

```sh
bun scripts/embedding-backfill.ts resume
bun scripts/embedding-backfill.ts backfill
bun scripts/embedding-backfill.ts rebuild
bun scripts/embedding-backfill.ts retry
```

- `resume` continues the committed cursor, including an interrupted rebuild.
- `backfill` starts a fresh scan for missing current-revision vectors. Existing failed jobs remain failed until explicitly retried.
- `rebuild` starts a fresh scan, removes the selected version's cache and replaces its jobs as each batch is processed. Older in-flight results cannot satisfy the new generation.
- `retry` resets failed jobs for eligible memories, allowing up to five new attempts after the underlying problem has been fixed.

These commands queue work; the server publisher and Python worker must run to generate vectors. Each scan transaction locks at most 100 memories by default (maximum 500), commits its cursor with the queued jobs, and can be safely interrupted. Restart interrupted maintenance with `resume`, not `rebuild`, to avoid deliberately restarting already-completed work. New versions scan independently and can coexist with old versions. Rebuilding does not change memory content or history.

## Exact-search boundary

The cache key is `(memory_id, model)`, with dimensions and content revision stored alongside the vector. `EmbeddingRepository.listVectors` filters by owner, exact model identity, dimensions, enabled registry entry, current revision and temporal eligibility. It returns bounded candidates, not nearest-neighbor rankings. Any future exact cosine query using pgvector's `<=>` must preserve all these filters and encode its query with the identical model contract. Comparing two different version spaces is invalid even when their dimensions match. No HNSW or IVFFlat index is introduced.

The existing `ContextRepository.putEmbedding` also requires the expected `contentRevision`; stale writes fail. It remains a lower-level cache API, while normal production generation uses registered models and durable jobs.

## Verification

`bash elyrii_server/scripts/test-context-db.sh` exercises migrations and PostgreSQL/pgvector behavior, including revision changes, replay, competing claims, expiry, deletion races, independent model versions, resumable scans, bounded retries, registration races and transactional failure recovery. `python -m unittest discover -s elyrii_ai/test` includes mocked Ollama contract, digest, timeout, malformed-output and worker-publication tests. No live model inference or English/French retrieval-quality benchmark is claimed by these tests.
