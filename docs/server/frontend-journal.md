# Journal integration with the new frontend

The journal runs on `feature/rafael-sapalo/frontend-backend-integration`, based
on `cleanup/frontend-dev-pr`. The existing inline composer, reader, edit sheet,
mood picker, search and navigation retain their design.

## Contracts

- Authenticated `GET /journal?limit=100&order=desc` returns
  `{entries, totalCount, nextCursor}`. Follow `nextCursor.createdAt` and
  `nextCursor.id` using `cursorDate` and `cursorId`. Both cursor fields are
  required together; limits are 1–100. Ascending order and optional inclusive
  `startDate` / `endDate` filters are supported. Calls without a limit keep
  the legacy array response.
- Ordering and comparisons use millisecond timestamps plus UUID, so timestamps
  with PostgreSQL microseconds and server timezones cannot skip tied rows.
  Each page and its total use the same repeatable-read database snapshot.
- `POST /journal` accepts `title`, `content`, `mood`, `tags` and an optional
  UUID `clientRequestId`. The editor retains one request ID per draft. Concurrent
  retries return the same note, even if the first response was lost. Later
  text/title/mood revisions are then saved with `PUT /journal/:id`. Replays do
  not repeat journal-created quest/activity hooks. A retry of a deleted note
  returns 409 and cannot resurrect it.
- Read, update and soft delete use `GET/PUT/DELETE /journal/:id`. Another
  account receives 404. The backend derives ownership from the access token.
- Cache and draft data stay encrypted and account scoped. A failed remote save
  keeps the draft; it never presents a draft as a server-confirmed note. Page
  refreshes reconcile only the cached range proven complete by that page, so
  remote deletions disappear offline without discarding unvisited older pages.
  Malformed page metadata cannot remove a confirmed local copy.
- Deleting an account also removes its journal entries, tags and media/join
  records in the account deletion transaction.
- Search retains its existing behavior over loaded entries; it is not a new
  full-history server search service.

## Migration

`0007_journal_mobile_contracts.sql` adds a nullable request UUID, a unique
account/request index, and the cursor index. Existing notes stay intact and
legacy clients can omit the request UUID. Apply ordered migrations through
`bun run db:migrate` on the intended development/staging backend before using
this frontend. No migration has been applied to a shared or production database.

## Reproducible local verification

```sh
cd elyrii_server
POSTGRES_BINDIR=/opt/homebrew/opt/postgresql@17/bin bun run test:journal
```

This shared connected runner starts disposable PostgreSQL and a local API,
runs auth/profile/mood plus journal HTTP regressions and the actual Dart
providers, then stops its services. It applies the baseline schema, context
generation column, recovery migration and journal migration. It does not
validate the separate pgvector/AI migration chain; use the existing
`scripts/test-context-db.sh` workflow for that.

To also exercise the actual native journal screens, supply an already-booted,
dedicated simulator (the test uses disposable accounts and native credentials):

```sh
POSTGRES_BINDIR=/opt/homebrew/opt/postgresql@17/bin \
IOS_SIMULATOR_UDID=<dedicated-udid> \
IOS_CONNECTED_TEST=integration_test/journal_connected_test.dart \
bun run test:journal
```

The native flow writes and edits a note through the existing screens, verifies
the running API response, rebuilds the app state while retaining native
Keychain/SQLite, opens the restored note and confirms deletion. This is a fresh
Flutter app bootstrap, not a force-kill/relaunch or physical-device test.

## Verification on 10 November 2026

- Flutter analysis and TypeScript checking: no issues; Bun build passed.
- Final Flutter suite: 508 passed, two opt-in connected tests skipped and
  subsequently verified through the connected runner.
- Backend default suite: 29 passed, 93 opt-in database/AI cases skipped.
- Disposable PostgreSQL/API: 13 backend tests and two real Dart provider
  flows passed. Journal cases cover concurrent retry IDs, account isolation,
  CRUD, 126 notes paged across timestamp ties in both directions, invalid
  cursors, deleted-note replay and account cleanup.
- Dedicated iOS 27 simulator: the actual journal create/edit/restore/delete
  flow passed. The simulator browser displayed a live frame and the confirmed
  deletion toast. Temporary services, mirror and simulator were stopped.
- One earlier full run during the native build hit the previously observed
  meditation timer assertion; the final complete run passed without changing
  meditation code.
- No shared/production database, deployed API or physical device was tested.
