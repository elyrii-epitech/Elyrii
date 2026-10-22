# PostgreSQL context storage

This change implements storage and container setup for the three context layers.
It does not extract memories, generate embeddings or summaries, retrieve context,
assemble prompts, expose memory APIs, or run retention cleanup jobs.

## Organization

All records stay in one PostgreSQL database alongside the existing application
tables. Existing user IDs, messages, conversation IDs, and repository interfaces
are preserved. The new context tables are initially empty.

| Context | Tables | Intended use |
| --- | --- | --- |
| Stable facts and preferences | `user_context_facts` | Structured JSON values under named keys, read directly for a user |
| Conversation continuity | Existing `chat_messages`, new `conversation_summaries` | Recent messages plus one rolling summary per user/conversation |
| Relevant past experiences | `user_memories`, `memory_embeddings` | Readable memories with optional, rebuildable semantic search vectors |

Facts and memories distinguish explicit statements from inferred information and
have `active`, `superseded`, or `deleted` status. Only one active fact is allowed
per user/key. A correction should supersede the previous fact and insert its
replacement in one transaction. `updated_at` is maintained by Drizzle on writes;
direct SQL writers must update it themselves.

Memory timing has three distinct meanings:

- `event_at`: when the experience happened, if known.
- `valid_from` / `valid_until`: when it describes the user's current situation.
- `expires_at`: when it should stop being retained. Short-term memories require
  an expiry; long-term memories may also have one.

These fields are metadata only: PostgreSQL does not automatically expire or
delete rows. Future readers must filter by owner, active status, validity, and
expiry. Future cleanup must remove expired records. Temporary emotions must not
be interpreted as permanent facts simply because their history is retained.

Composite foreign keys prevent facts/memories from referencing another user's
message and summaries from referencing another user or conversation. A summary's
`through_message_id` identifies its coverage boundary. Source-message deletion
cascades to records that directly reference it, including their embeddings;
deleting a user cascades through all their new context storage. Deleting other
messages covered by a summary still requires future summary invalidation logic.
These constraints enforce ownership of links, not read authorization: queries
must still scope to the authenticated user.

The vector column deliberately has no fixed dimension: no embedding model has
been chosen. Each vector records a model/version identifier and dimension count,
checked against `vector_dims(embedding)`. There is one vector per memory/model.
Future search must join through the owning memory, filter model and dimensions,
and exclude inactive/expired memories. Content changes require re-embedding.
There is no ANN index yet; a future model-specific migration can add one when its
dimension and distance metric are known. See the [pgvector documentation](https://github.com/pgvector/pgvector).

## Application storage API

`ContextRepository` in `elyrii_server/repository/context.repository.ts` is bound to
one trusted user ID at construction. Callers must obtain this ID from verified
authentication or a validated internal job, never from a model candidate. A UUID
alone is not authentication. The database and `ContextPolicy` can be injected for
tests. This API is not yet wired into chat, inference, or HTTP routes.

The strict candidate contracts in `modules/context/context.candidates.ts` define
facts/preferences (`kind`, `key`, JSON `value`) and memories (`kind: memory`,
readable `content`, `retention`). Both require `origin` and a source message ID.
The repository checks that the source belongs to its user and has role `user`;
assistant statements cannot become user facts. Unknown fields such as `userId`,
`status`, or candidate-supplied record IDs are rejected. Wire timestamps are ISO
8601 strings with an explicit offset; validation converts them to UTC instants.

| Operation | Behavior |
| --- | --- |
| `createFact`, `replaceFact(expectedId, candidate)` | Create or atomically supersede the active fact for the same key. User-row locking serializes concurrent writes; stale expected IDs fail. |
| `createMemory`, `correctMemory(id, candidate)` | Store a memory or supersede it with a new ID, deleting the old embeddings in the same transaction. |
| `listEligibleFacts`, `listEligibleMemories` | Return only the user's active records whose validity has begun and not ended, excluding expired memories. Results are bounded (default 100, maximum 200). |
| `getFact`, `getMemory` | Owner-scoped inspection, including superseded/deleted records; these are not eligibility-filtered retrieval methods. Foreign or missing IDs return null. |
| `putSummary`, `getSummary` | Store/read a summary for exactly one user/conversation, validating its boundary message. |
| `getRecentMessages` | Return a bounded chronological slice ordered by `(created_at, id)`, including stable UUID ordering for timestamp ties. |
| `putEmbedding`, `getEmbeddings` | Access vectors through the owning eligible memory, validate model/dimensions, and serialize writes against corrections using the memory row lock. |

Memory corrections use a new ID rather than changing the content under an
existing vector. Late embedding writes to a superseded ID are rejected. Fact and
memory history remains available for inspection but is excluded from eligible
reads. Invalid corrections roll back without losing the previous active record
or its vectors. Direct SQL writes must preserve these invariants themselves.

`ContextPolicy` uses an injectable clock, sampled once per eligible read or after
acquiring write locks. Validity is `valid_from <= now < valid_until`, and retention
is `now < expires_at`; null end times are unbounded. The short-term retention
configuration is in milliseconds and defaults to **48 hours**, bounded by **1 hour
and 7 days** from persistence time. Callers can inject different validated bounds.
Missing/null short-term expiry receives the default; supplied expiry outside the
bounds is rejected rather than silently changed. Long-term expiry defaults to
null, but an explicit expiry must be in the future. Event time is independent and
never used to extend validity or retention.

Summary generation, stale-summary job detection/coverage tracking, semantic
ranking, cleanup, and forget/replay suppression remain in the subsequent issues.
The current summary upsert is a storage primitive, not a concurrent summarizer.
Likewise, stored expiry metadata does not automatically delete rows.

The isolated database test runner below now also executes repository and policy
tests. Ordinary `bun test` runs policy tests and skips database integration unless
`CONTEXT_DB_TEST=1` is explicitly set. Prefer the Docker runner so tests never use
an application database. The tests cover owner/source isolation, exact temporal
boundaries, rollback, concurrent correction, vector invalidation, and message ties.

## Containers and fresh databases

All three PostgreSQL Compose definitions use
`pgvector/pgvector:0.8.6-pg16-bookworm`, persistent volumes, and a database-specific
health check. The init script enables `vector` in the configured database. A
one-shot `db-migrate` container then applies checked-in migrations; application
containers wait for it to finish successfully. PostgreSQL can start without Kafka
or AI services. Local published database ports bind to loopback.

From the repository root, start only the database infrastructure:

```sh
docker compose -f docker_compose_postgres.yml up -d --build
docker compose -f docker_compose_postgres.yml logs db-migrate
```

Defaults are `DB_USER=postgres`, `DB_PASSWORD=postgres`, `DB_NAME=elyrii_db`, and
host port `DB_PORT=5432`. Override these through the environment or Compose's
`.env` file; use a private password outside local development. Inside the Compose
network, PostgreSQL always listens on `postgres:5432`.

For a fresh full stack, use `docker-compose-vm.yml` or
`elyrii_server/docker-compose.yml` instead. Do not start multiple definitions
against the same volume simultaneously. Keep the original Compose file/project
when upgrading: the files have different volume names and are not interchangeable
connections to one database. Container recreation preserves the volume; removing
volumes deletes the database.

## Existing databases created with `db:push`

Migration `0000_existing_schema.sql` is the previous application schema.
`0001_three_context_storage.sql` adds the new tables, extension, ownership keys,
and indexes without rewriting existing message or user data. Fresh databases run
both; existing databases must explicitly adopt the baseline first.

Stop application writers and take a backup using the existing PostgreSQL image
before replacing it. For example, using your deployment's original Compose file:

```sh
export COMPOSE_FILE=docker_compose_postgres.yml
docker compose exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB"' > elyrii-before-context.sql
```

Use the same `COMPOSE_FILE`, project name, credentials, database name, and volume
throughout the upgrade. This remains PostgreSQL major version 16, but the image
changes from Alpine to Debian; check existing locale/collation compatibility.
Where necessary, restore the logical backup into a fresh volume rather than
reusing incompatible data files. Never delete the original volume to retry an
upgrade.

After updating the repository, start PostgreSQL and build the migration image:

```sh
docker compose up -d postgres
docker compose build db-migrate
docker compose run --rm db-migrate bun run db:baseline
docker compose run --rm db-migrate
```

`db:baseline` creates a disposable reference schema inside a transaction and
compares the existing public tables, columns, defaults, constraints, and indexes
to migration 0000. It records the baseline only if they match, then removes the
reference schema. A mismatch rolls the transaction back without modifying
application tables or recording migration history. Reconcile differences before
retrying; do not force a baseline onto an unknown schema. Databases with an
existing migration journal should use `db:migrate`, not baseline again.

Check that migration completes successfully before restarting application
services. The migration adds indexes/constraints and can take locks on large
message tables, so schedule an appropriate maintenance window. Rollback is by
restoring the backup; automatic destructive down-migrations are not provided.

## Development and verification

With Bun installed, server commands can also run directly using the `DB_*`
environment variables:

```sh
cd elyrii_server
bun run db:generate
bun run db:migrate
```

Review generated SQL before committing. Migration 0001 explicitly enables the
extension and places message uniqueness constraints before the composite foreign
keys that reference them. Do not edit already-applied migrations. `db:push` remains
available for disposable development databases only; it does not maintain the
migration journal and is no longer used by container startup.

Run the isolated PostgreSQL integration tests from the repository root:

```sh
bash elyrii_server/scripts/test-context-db.sh
```

They build the migration image, use an unexposed PostgreSQL container on tmpfs,
and remove it on completion. Checks cover custom database/user names, fresh
installation, repeat migrations, upgrades preserving existing messages, rejection
of schema drift, ownership and validity constraints, dimension checks, and
deletion cascades. No application database is contacted.
