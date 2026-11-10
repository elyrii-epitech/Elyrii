# Home extras integration

The existing Accueil, Journal question picker, Garden activities and scene
selector retain their layout and controls. Real accounts synchronize checked
rituals, added rituals, social completions and idea choices, journal follow-up
answers, the selected daily journal question and Home scene. Guest/demo behavior
stays local. The separate device mood mirror used by Mon bilan is unchanged;
daily mood saving already uses its existing API.

## Backend and concurrency

Authenticated endpoints under the user gateway are:

- `GET /user/home`: `{schemaVersion: 1, owner, revision, activities}`; revision
  zero means that the account has no saved Home document yet.
- `POST /user/home/import`: `{owner, activities}` initializes an empty account.
- `POST /user/home/commands`: `{requestId, command}` changes one part of Home.
  Commands cover `ritual`, `addRitual`, `socialComplete`, `socialIdea`, `thread`,
  `decor` and `question`.

Responses use `Cache-Control: no-store`. Requests validate date strings, rituals,
scenes and command payloads. Civil dates remain `YYYY-MM-DD`; social weeks are
anchored on Monday without timezone conversion. New completion timestamps come
from the server. Home retains roughly 370 days and the latest 50 follow-ups.

Each command locks its owning account and updates the current document, so a
second device's unrelated edits are preserved. A unique account/request receipt
and payload hash make repeated command delivery idempotent, including social
idea and question advances. Reusing a request ID for a different command is a
409. Receipts and the document commit together. Journal answers require an active
owned note and keep the first answer. Clairière requires ten completed challenges
according to server records; a client-supplied count cannot unlock it. These
Home commands do not award challenge points.

## Existing device data and failures

The first upgraded device can initialize the account with its previous encrypted
Home data. The original document is retained as an encrypted account-owned
`accueil_activities_legacy_<owner>` backup. Existing server data always wins over
a later device's legacy import; old checked items cannot resurrect an item
another device has unchecked. Other device history remains in its local backup
and export. Foreign/deleted-note follow-ups are filtered during import and a
locked legacy scene falls back to Arches.

Confirmed server state is cached with the existing account content cipher.
Writes appear optimistically and are confirmed by the API. Failed writes roll
back and expose the existing reload control. A lost response can mean the server
saved the change; reloading reconciles the result. There is no durable offline
write queue. A cached snapshot can still be read after a failed load, while new
Home changes wait for a successful reload. A cache write failure does not undo
an acknowledged server command.

Home refresh and app foregrounding reload account activities. Account/session
checks fence late reads and writes. Account export includes the remote Home
document plus local Home data and the migration backup. Account deletion removes
the server document/receipts by foreign-key cascade and clears both device keys.

## Migration and validation

Apply migration `0010_home_activities.sql` through `bun run db:migrate` before
deploying this client/backend combination. It creates `home_activities` and
`home_commands`; it does not modify existing journal or mood rows.

```sh
cd elyrii_server
bun run test:home
# IOS_SIMULATOR_UDID=<owned-simulator> also runs the native UI flow.
```

The local runner creates disposable PostgreSQL/API services with UTC database
timestamps, matching the existing journal timestamp contract. Backend tests cover
validation, ownership, one-time import, interleaved device commands, duplicate
delivery, locked scenes, export and deletion. A real Dart client also exercises
encrypted migration, restoration without cache, network failures, lost
acknowledgements and authentication changes during pending reads/writes.

The native flow uses the real new frontend and native storage to change rituals,
follow-ups, social steps, journal questions and scene, then restores them after
clearing the fixture's Home cache. Simulator-browser QA checks a live frame.
These are local checks; they do not establish deployed or physical-device proof.
