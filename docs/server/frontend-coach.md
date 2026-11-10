# Coach integration with the new frontend

Branch: `feature/rafael-sapalo/frontend-backend-integration`, based on
`cleanup/frontend-dev-pr`.

The new Coach tab is the guided-programs screen in `features/parcours`. Its
catalogue, cards, topic filters, program and step sheets, confirmation controls,
journal/meditation links and completion presentation retain their design. The
storage note and error copy now describe account synchronization accurately.

## Backend contracts

The existing `/coach/sessions` prompt/response API remains available. The new
tab uses these authenticated program endpoints instead:

- `GET /coach/catalog`: the same three version-2 programs shipped by Flutter,
  including all editorial text and journal/meditation actions.
- `GET /coach/journey`: `{schemaVersion: 1, owner, current}`.
- `POST /coach/journey/choose`: `pathId`, `contentVersion` and nullable
  `expectedEnrollmentId`.
- `POST /coach/journey/pause` and `/resume`: `enrollmentId` and `revision`.
- `POST /coach/journey/steps/:stepId/complete`: `enrollmentId` and `revision`.
- `POST /coach/journey/import`: a validated legacy enrollment snapshot.

Mutations return `{current, changed}`. The server serializes changes under an
account lock, validates revisions and current enrollment identity, and permits
only the current step to advance. Matching retries return unchanged progress;
stale or conflicting commands require a refresh. Duplicate completion requests
cannot skip another step. A paused program cannot advance, and a completed
program cannot be resumed or reset by reselecting it.

Program replacements archive the previous enrollment and create a new one.
A partial unique index allows only one current enrollment per account. Every
enrollment keeps its own content snapshot, progress, revision and UTC timestamps.
Foreign enrollment IDs return 404; account deletion cascades to all enrollments.
Confirmed new step completions update the existing activity streak. They do not
grant challenge rewards or create synthetic legacy coaching responses.

Journal notes and meditation sessions opened from Coach use their existing
connected flows. Returning from an activity does not automatically complete a
step: the existing “Terminer l’étape” confirmation remains required.

## Device progress and offline behavior

Real accounts now load the catalogue and progression from the backend. If the
account has no server program, the client imports its existing encrypted local
enrollment. Identity, status, count and revision survive migration; timestamps
are normalized to UTC milliseconds. Known structurally unchanged version-1
content receives the existing editorial refresh. Other valid version-1 snapshots
stay frozen. Version-2 imports must match the server catalogue.

An existing server enrollment always wins over a device cache or repeated import.
Import cannot overwrite progress created by another device. If migration is
needed, unsupported or corrupt local data is retained and surfaced as an error,
not silently cleared.

Confirmed remote snapshots are cached in the existing encrypted per-account
preferences. On network/server failure they can be read, with an offline notice
and new program mutations disabled until a successful refresh. Failed or lost
mutation responses do not report success; refreshing reconciles the server
state. No offline mutation outbox is added. Demo progress remains local.

Requests check both the expected account owner and API session generation.
An old account's pending read or queued command cannot become the replacement
account's progress. Local purge/export operations retain their account scope.

## Required database migration

Apply `0009_coach_journeys.sql` through the normal server migration command before
using the new endpoints in a deployed environment:

```sh
cd elyrii_server
bun run db:migrate
```

It adds `coach_journeys`, its ownership foreign key, progress constraints and
current-program unique index. It does not rewrite existing coaching sessions.
The migration is registered in `migrations/meta/_journal.json`.
No deployed database was changed by this milestone.

## Reproducible local checks

```sh
cd elyrii_server
POSTGRES_BINDIR=/opt/homebrew/opt/postgresql@17/bin bun run test:coach
```

The runner starts disposable local PostgreSQL and the real HTTP API, applies the
coach migration, checks program contracts and real Dart providers, then stops
its services. Kafka and the AI model are not required. The default
auth/profile/mood/journal runner remains available.

For native screens, supply a dedicated booted simulator:

```sh
POSTGRES_BINDIR=/opt/homebrew/opt/postgresql@17/bin \
IOS_SIMULATOR_UDID=<dedicated-udid> \
HOLD_COACH_QA_FRAME=true \
bun run test:coach
```

The native flow chooses a program, opens and completes linked meditation and
journal activities, explicitly completes steps, pauses/resumes, confirms a
replacement program, and restores server progress after removing only the
fixture account's local journey cache. The optional hold exposes the completed
program in the simulator browser. This is bootstrap verification rather than a
force-kill/relaunch, deployed-service or physical-device test.

## Verification on 2026-11-10

- Flutter analysis: no issues. Full Flutter suite: 515 passed; six opt-in
  connected checks skipped by default. The focused journey suite passed 32 tests.
- Coach runner: seven backend HTTP/database checks, one real Dart flow and one
  native iOS flow passed against disposable local PostgreSQL/API.
- Checks cover concurrent choices, lost step acknowledgements, ordered progress,
  pause/resume, legacy migration, server authority over a stale cache, offline
  reads, account replacement and deletion, and exact frontend/catalogue parity.
- The native flow passed linked meditation and journal activities, explicit step
  confirmation, program replacement and restoration after removing the fixture's
  local journey cache. The simulator browser showed the completed program.
- Baseline auth/profile/mood/journal regression: 13 backend checks and two real
  Dart flows passed with the coach migration present.
- Backend TypeScript validation and build passed. The clean default Bun suite
  passed 32 checks with 130 opt-in checks skipped.
- An initial simulator startup stalled and interrupted the first broad check
  attempt. Final results above come from clean reruns after stopping only the
  dedicated QA device's processes. The test services, mirror and QA simulator
  were stopped, the device deleted, and disposable database data removed.

These checks do not establish deployed-service, live AI or physical-device proof.
