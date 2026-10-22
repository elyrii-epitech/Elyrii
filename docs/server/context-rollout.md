# Budgeted context rollout

Persistent context is integrated into the server-to-AI chat path behind **`ENABLE_PERSISTENT_CONTEXT=false` by default**. Both the server and bridge must run the new version and use the same flag. Disabling it restores the ordinary `/api/chat` path, with the duplicate-current-input fix retained. Apply migrations through `0006_mood_context_suppression` before deploying mood context; lifecycle migration 0005 and the earlier context migrations remain prerequisites.

## Request and privacy boundary

After persisting the current input, the server retrieves structured facts, continuity and memories. Its Kafka envelope adds:

```json
{
  "context": {
    "version": 1,
    "ticket": "short-lived signed capability",
    "sections": { "facts": [], "continuity": { "summary": null, "messages": [], "truncated": false }, "memories": [], "semanticStatus": "ok" }
  }
}
```

Existing `userId`, `sourceMessageId`, `conversationId`, `message`, and `history` fields remain compatible. History queries exclude `sourceMessageId` before limiting. The current input is sent once, separately from uncovered history.

The bridge **does not trust queued sections or queued history when the feature is on**. Immediately before prompt composition, it posts the ticket to `/internal/chat-context/refresh` on the configured server. The signed ticket binds owner, conversation and source ID, expires after two minutes, and cannot select arbitrary users. The server loads the current saved input, runs fresh retrieval, and rechecks the input after retrieval. Deleted, suppressed or concurrently changed inputs return 410. Corrected/deleted memories and expired context are rechecked through the retrieval/lifecycle policies. The bridge also validates the returned identity, ownership and timestamps before selecting fields.

Fresh context is a point-in-time snapshot; a later deletion cannot retract an already submitted inference request. AI responses carry their source ID and a hash of the input actually used; the server rechecks that source under the owner lock before saving or delivering the answer. A corrected, suppressed or deleted source therefore cannot receive a late answer or seed future summaries with it. No cached Kafka context is used as a fallback. Tickets contain IDs and an expiry, not message text; treat them as credentials and keep the bridge/server connection on a trusted network or TLS. The bridge needs the server URL but **does not need the signing secret**.

The initial retrieval deadline defaults to four seconds. Refresh has an outer server deadline and a three-second retrieval sub-deadline, with a five-second HTTP deadline at the bridge. A successful source check with unavailable retrieval returns `sections: null`, allowing budgeted current-input-only chat. If the source itself cannot be verified, the bridge asks the user to send a new message instead of submitting potentially deleted queued text. Missing tokenizer artifacts likewise return a temporary-unavailability response; they never cause unbudgeted inference in the enabled path. Oversized current input receives an explicit request to shorten or split it.

Optional initial Kafka sections are capped at 250 KB, and refreshed sections at 500 KB. Larger sections fall back to the verified current input. History failures and extraction/embedding outages do not prevent dispatching the user's input. Underlying database work may finish after a request deadline, but its late result is not attached to that request.

## Native tokenizer and prompt contract

The enabled bridge uses `/api/generate` with `raw: true`, so it owns and measures the entire rendered prompt. It does not rely on an unseen Ollama chat template or Modelfile system text. All required instructions must therefore be present in the Python system prompt.

Provision a local read-only directory containing the **actual generation model's** `tokenizer.json`, `tokenizer_config.json`, native `chat_template.jinja`, and a reviewed `manifest.json`:

```json
{
  "model": "elyrii-lora",
  "digest": "FULL_LOWERCASE_64_HEX_OLLAMA_ARTIFACT_DIGEST",
  "tokenizerSha256": "SHA256_OF_tokenizer.json",
  "configSha256": "SHA256_OF_tokenizer_config.json",
  "templateSha256": "SHA256_OF_chat_template.jinja",
  "contextWindow": 4096,
  "responseTokens": 512,
  "systemMode": "fold"
}
```

The example digest/hash strings are placeholders and intentionally do not form a valid manifest. Obtain the serving artifact digest from Ollama `/api/tags` and hash the local files with `sha256sum`. For the VM's Mistral-v0.3-derived adapter, use that base model's exact tokenizer and instruction template, not a v0.2 tokenizer or an unrelated embedding tokenizer. The manifest must name the exact served tag, including any `:latest` suffix returned by `/api/tags`; configure `AI_MODEL` consistently. No tokenizer/model files are downloaded automatically.

`systemMode: system` uses native system and user roles when supported. `fold` places the trusted instruction prefix before the user data inside the single instruction turn, for native templates without a system role. This choice must match the generation model's trained format and be reviewed with its tokenizer/template. Template rendering uses a sandboxed Jinja environment and verifies that required instructions and the single input payload survived rendering.

The bridge verifies all file hashes at startup and checks the serving model digest before and after inference. Do not change the serving model in place while requests are active. Pinning prevents accidental artifact drift; the operator must still verify that the tokenizer/template belong to the selected model, since a file hash alone cannot establish that relationship.

Budgeting tokenizes the complete rendered native template, including instructions, attributed data, current input, BOS and generation prefix. It reserves `responseTokens` and an additional eight slots for provider-side BOS/EOS handling, and sends `num_ctx`/`num_predict` explicitly. Optional records are admitted whole in this order:

1. Direct preferences, then other direct facts.
2. Rolling summary, then newest uncovered messages (rendered chronologically).
3. One eligible dated mood observation (at most 256 additional native tokens, including its attribution and trusted mood instructions).
4. Ranked semantic memories.

At most 128 facts, 64 recent messages and 50 memories are considered per composition to bound work. Required instructions and current input are never silently truncated. If those alone do not fit, no inference runs. The composer re-counts after final ordering and removes lowest-priority optional records if token boundaries changed. Provider `prompt_eval_count`, when available, is checked against the window plus response reservation; discrepancies fail the response and require investigation.

Retrieved records are serialized as attributed JSON in a fixed user-data payload. Historical speaker names remain data fields; they are never replayed as system/tool messages. Native control-token strings inside data are escaped. The trusted policy explicitly rejects instructions and role claims in historical content, and distinguishes past emotions from current state. Structural injection tests verify role/control-token isolation. They are not proof that a language model can never follow a malicious natural-language instruction; live adversarial response evaluation remains required.

## Deployment configuration

| Variable | Scope | Default / requirement |
| --- | --- | --- |
| `ENABLE_PERSISTENT_CONTEXT` | server and bridge | `false` |
| `ENABLE_MOOD_CONTEXT` | server | `false`; also requires persistent context enabled |
| `MOOD_CONTEXT_FRESHNESS_HOURS` | server | 48; integer 1–168 |
| `CONTEXT_BRIDGE_SECRET` | server only | Required when enabled, at least 32 characters of random secret material |
| `CHAT_RETRIEVAL_TIMEOUT_MS` | server | 4000; range 1–10000 |
| `CHAT_TOKENIZER_DIR` | bridge | Required local directory when enabled |
| `CHAT_TOKENIZER_HOST_DIR` | Compose | Host directory mounted read-only at `/generation-tokenizer` |
| `CONTEXT_SERVER_URL` | bridge | VM uses the server service; AI-only Compose uses the host gateway |
| `AI_MODEL` / `OLLAMA_MODEL_NAME` | deployment | Must exactly match manifest and serving tag |

Set up embedding generation, retention cleanup and the matching retrieval model first. Upgrade both components while the flag is off, provision reviewed artifacts, run the evaluations below, then enable for a controlled deployment cohort. Roll back by disabling the flag on both components. No Flutter UI is added.

## Metrics and evaluation gates

Structured `chat_context` logs contain stage, elapsed milliseconds, outcome and numeric counts only. Stages cover retrieval, refresh, composition and generation. Composition records input tokens, reserved/window tokens, dropped records and selected-memory count (zero identifies empty recall). Failure outcomes distinguish configuration failure, unavailable refresh, oversized input and generation failure. Raw chat logging and SQL-exception logging in the affected dispatch/persistence paths have been removed. HTTP access logs contain paths, not ticket bodies or message text.

Run the reproducible synthetic pipeline with Docker and a Python environment containing `requirements-bridge.txt`:

```sh
EVAL_PYTHON=/path/to/venv/bin/python bash elyrii_server/scripts/evaluate-context.sh
```

It creates isolated PostgreSQL/pgvector databases, performs extraction reconciliation, asynchronous embedding completion, rolling summarization, retrieval, corrections, forgetting and refresh, then feeds the exported responses into the Python composer. `report.json` contains per-case retrieval/composition timings and token counts. No production data is used. To measure the actual tokenizer/template against these fixtures, also set `CHAT_EVAL_TOKENIZER_DIR` and `AI_MODEL`; this still does not run live generation.

The evaluation set covers:

| Case | Required result |
| --- | --- |
| Preference from another conversation | Direct preference remains present |
| Old graduation experience | Included for a relevant query, absent for unrelated query |
| Monday sadness after its retention window | Absent from recalled context |
| Rolling continuity | Summary present without covered/current input duplication |
| Correction before re-embedding | Old and not-yet-embedded replacement both absent |
| Correction after re-embedding | Only replacement appears |
| Forgetting | Neither old nor corrected memory appears |
| Foreign user | No foreign marker reaches the prompt |
| Injection/control-token strings | No new system/tool role or native boundary tokens |
| Provider/retrieval failures | Verified input-only chat or explicit safe retry response |
| Current input exceeds window | No inference; explicit shortening response |

The checked-in [synthetic measurements](context-rollout-evaluation.json) are regression evidence using a small local test tokenizer and mocked providers. They are **not production latency, retrieval-quality or model-safety measurements**.

**Enablement review is pending.** Before changing the default, a deployment reviewer must record the artifact digests, actual tokenizer results, live prompt/output token counts, p50/p95 retrieval and generation latency, relevant/unrelated recall quality in English and French, and adversarial-response results. Repeat deletion/correction tests with queued requests, verify failure/rollback behavior, and document the accepted latency/error thresholds and reviewer/date. No production tokenizer artifacts or live generation evaluation were available for this implementation; the feature remains off.


## Dated mood-log context (#229)

Mood context reads only `mood_logs` for the authenticated owner. It does not read journal or meditation moods, classify chat sentiment, create facts/memories/embeddings, infer trends, or write back to the tracker. `sections.moodObservation` is optional and separate from the other context layers:

```json
{
  "source": "mood_logs",
  "logId": "22222222-2222-4222-8222-222222222222",
  "userId": "11111111-1111-4111-8111-111111111111",
  "mood": "sad",
  "observedAt": "2030-04-01T10:00:00.123456Z",
  "freshUntil": "2030-04-03T10:00:00.123456Z",
  "timezone": "Europe/Paris"
}
```

The supported tracker values are `verySad`, `sad`, `neutral`, `happy`, and `veryHappy`. Reads normalize casing and surrounding spaces to these canonical values. Other legacy free text is ineligible and never enters the prompt. This does not rewrite stored logs. The latest **eligible** row wins by `created_at DESC, id DESC`; an unsupported or future-dated newer row is skipped. No eligible check-in means unknown.

Freshness is `observedAt <= now < observedAt + configured window`, computed in SQL from the source timestamp, not from lookup time. Exactly at the end, it is omitted. The default 48 hours is an initial product policy, not a claim about how long an emotion lasts. Timestamp-without-time-zone tracker storage follows the application's UTC convention; output explicitly uses UTC with six fractional digits. The user's validated IANA timezone is only for display/relative dates (UTC fallback for invalid settings), never for shifting eligibility. The bridge preserves the instants and rechecks future/expiry boundaries before composition.

The global persistent-context switch and independent mood switch must both be on. `privacyMode=STRICT` excludes mood context. Migration 0006 adds `mood_logs.context_suppressed`; forget-all marks existing tracker rows as excluded without deleting them, and a trigger makes this exclusion durable. A new check-in can be eligible again. Deleting a tracker log removes it from subsequent refreshes. Existing suppressed/deleted current chat inputs cannot refresh any context.

Every retrieval, including signed prompt-time refresh, performs a fresh mood lookup after embedding/assembly. No Kafka mood snapshot is a fallback. Mood lookup runs outside the facts/continuity transaction and has a 250 ms attachment deadline; failure, invalid configuration, timeout, or absence leaves other usable context intact. A late result is ignored. As with other context, refresh is a point-in-time read: deletion after refresh cannot retract a submitted inference request.

Required instructions and current input always take precedence. Facts/preferences and continuity are allocated before mood; semantic memories follow it. The observation is admitted whole only if its incremental cost, including dedicated trusted instructions, is at most 256 tokens measured by the pinned generation tokenizer and the full prompt fits with response reservation. It is omitted rather than truncated. All mood fields are untrusted attributed JSON; unsupported mood text and native-role injection are rejected before budgeting. The trusted policy requires dated tracker attribution when relevant, does not assume a past feeling persists, and gives the current user's explicit description precedence. Missing or repeated check-ins do not imply personality, diagnosis, or trend.

Telemetry adds only `selectedMoodObservations` (0 or 1). No raw mood value, log ID, timestamp, or prompt is logged by this integration. Tracker history is not deleted on freshness expiry.

### Reproducible tests and response review

Run `bash elyrii_server/scripts/test-context-db.sh` for isolated PostgreSQL tests, including normalization, owner isolation, equal timestamps, microseconds, DST display, exact expiry, privacy/forget-all, lookup failure, and refresh after replacement/deletion. Run `python -m unittest discover -s elyrii_ai/test` with the bridge requirements installed for validation, stale Kafka exclusion, whole-record budget omission, injection, and English/French prompt fixtures.

`elyrii_ai/test/fixtures/mood_context_v1.json` contains ten synthetic English/French response-evaluation cases: dated attribution, current-message conflict, unknown mood, expired mood, and malicious legacy text. Each includes a review rubric. Prompt tests use a small test tokenizer; they do not establish live response quality. Generate responses with the actual pinned serving artifacts:

```sh
python -m elyrii_ai.scripts.evaluate_mood_context \
  --tokenizer-dir /path/to/pinned-generation-tokenizer \
  --model elyrii-lora --url http://localhost:11434 \
  --output /tmp/mood-response-evaluation.json
```

The runner fixes the synthetic scenario date, language, seed, and temperature, verifies the model digest before/after inference, checks token limits, and writes responses with rubrics for human review. Reviewers must check dated attribution and current-message precedence in both languages, absence of inferred diagnoses/trends, and injection resistance. The report intentionally starts with `review: pending`; do not treat a successful HTTP response as a passed behavioral evaluation.

Implementation validation passed the database and Python regression suites. Live model response review remains pending: no pinned generation tokenizer/template/manifest was available in this checkout. Mood rollout remains off by default until that review is completed.
