# Journal context source foundation

Issue #233 adds provenance and lifecycle storage for journal-derived context.
[Journal inference/dispatch (#230)](journal-extraction.md) is separately opt-in;
[Journal retrieval (#231)](journal-recall.md) is separately opt-in and defaults off. Conversation
summaries and the existing v1 extraction wire contract remain chat-only.

## Provenance and events

Facts and memories may reference `{ kind: "chat" | "journal", id, revision }`.
Composite foreign keys enforce ownership, source existence and revision identity.
The legacy `sourceMessageId` remains populated for chat; manual records may have no
source. Inspection and correction responses add a `source` object without removing
legacy fields. Journals never require a synthetic conversation or chat message.

`context_source_versions` stores immutable source identity and original creation
time, plus active/excluded flags. `context_source_events` is a transactional outbox
containing metadata only, with one event per source revision and change type.
Journal creation, title/content/mood changes, exclusion and soft deletion produce
events atomically with the source write. Tags, media and incidental `updatedAt`
changes do not create revisions. Existing journals receive dormant creation events.
The original creation time cannot change; a deleted entry cannot be restored and
an excluded entry cannot be re-enabled through updates.

The internal v2 result DTO is shared by TypeScript and Python. It carries an event,
owner, generation, typed source and candidates; it accepts neither a conversation
nor caller-selected expiry. `ContextSourceRepository.apply` validates the event,
locks the owner, fences revisions and forgetting generations, and commits accepted
candidates and event completion together. Duplicate completion is idempotent.
This is a persistence boundary, not an exposed extraction endpoint or consumer;
future inference must validate candidate evidence before invoking it.

## Invalidation, time and privacy

Editing or soft-deleting a source immediately supersedes its old derived facts and
memories, clears vectors and invalidates pending embedding/extraction work. Late
results cannot revive an old revision. Authenticated journal writes and result
application lock the owner before the source to serialize competing operations.
Physical source deletion cascades through provenance and events; the public soft
delete path retains a durable deletion event. Account deletion also cascades through
journal tags and media metadata.

Source creation time, a described event time, and context validity are separate.
Short-term memory expiry is anchored to the earlier of original source creation
and supplied event time, with the default 48-hour lifetime. Delayed processing or
editing an old entry never restarts that lifetime. Expired candidates are skipped;
less than the usual minimum lifetime remaining is not extended. Chat extraction
uses the same source-anchored rule.

Journal candidates never automatically replace an active fact, including a newer
chat fact or a user correction. Matching values retain their original attribution.
Suppressed fact keys remain blocked. Inferred candidates are not promoted by this
storage foundation. Arrival order is not treated as evidence recency.

Forgetting journal-derived context removes derived rows from that journal and
permanently excludes its retained source from processing. Forget-all also excludes
journals with no derived rows yet. Cleanup preserves this exclusion. Corrections
can remain active at the same revision after source exclusion; subsequent source
edits invalidate their old provenance, while the correction's key barrier remains.
Source-less/manual context keeps its existing behavior. Journal-derived records
are filtered from retrieval unless the separate journal recall flag is enabled;
excluded sources remain withheld even when enabled (see [recall](journal-recall.md)).

## Deployment and rollback

Back up the database and quiesce writers while applying migration
`0007_journal_source_foundation.sql` through `bun run db:migrate`, then deploy the
server. The migration preserves chat provenance and manual rows and backfills
original journal timestamps in SQL without a JavaScript precision round trip.
Existing v1 chat workers remain compatible. No journal worker or recall flag is
enabled by this migration.

Before deployment, check for legacy orphan journal owners:

```sql
SELECT j.id, j.user_id
FROM journal_entries j
LEFT JOIN users u ON u.id = j.user_id
WHERE u.id IS NULL;
```

Resolve any orphans according to the deployment's data policy before migrating;
the new ownership foreign key fails safely rather than silently deleting them.

For an application rollback, retain the migrated schema and its lifecycle
triggers. Do not drop source columns/tables while journal-derived data exists.
A full schema rollback requires restoring the backup; no destructive down
migration is supplied. Avoid logging journal contents or v2 candidate payloads;
outbox rows contain source metadata, not journal text.

## Verification

From the repository root, run `bash elyrii_server/scripts/test-context-db.sh`.
It uses isolated disposable PostgreSQL databases and covers fresh/repeated
migration, populated pre-0007 upgrades, ownership constraints, atomic rollback,
concurrent edits/results, duplicate application, stale embeddings, exclusion,
corrections, source-anchored expiry and unchanged chat compatibility.
The Python contract tests are in `elyrii_ai/test/test_context_sources.py`.
