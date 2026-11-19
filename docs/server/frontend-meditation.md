# Meditation integration with the new frontend

Branch: `feature/rafael-sapalo/frontend-backend-integration`, based on
`cleanup/frontend-dev-pr`. The library, duration capsule, previews, breathing
animation, written guidance, pause controls and summary retain their design.
The existing summary error area gains a retry action when saving fails.

## Connected behavior

The backend catalogue now recognizes all 12 exercise IDs shipped by Flutter,
including the nine curated library practices and dashboard/journey entry points.
Native practices accept whole-minute durations from 1 to 1439, matching the
controller; the library keeps its existing 3/5/10/15-minute choices. The three
legacy audio program IDs and their fixed durations remain supported. Native
guidance stays on the device and does not depend on the legacy audio URLs.

Authenticated routes:

- `GET /meditation/catalog`: supported practice metadata.
- `GET /meditation/sessions?limit=20`: owned history, newest first, limit 1–100.
- `POST /meditation/sessions/start`: practice `type`, planned `durationMinutes`,
  optional `moodBefore` and optional UUID `clientSessionId`.
- `POST /meditation/sessions/:id/complete`: completion with optional summary
  `moodAfter`, `moodBefore`, `notes` and legacy `endedAt`.
- `POST /meditation/sessions/:id/cancel`: interrupted session.

The mobile controller assigns a UUID once per local session. Start retries use
the same ID, so a lost acknowledgement cannot create duplicate history rows.
The UUID uses the existing database primary key; no migration is required.
Conflicting type/duration or ownership under the same ID returns 409.

Complete/cancel transitions lock the account and session. Matching retries
preserve the first end time; a completed session cannot become canceled and a
canceled session cannot become completed (409). Optional completion fields are
updated only when supplied, so saving a summary mood preserves notes and time.
Foreign session IDs return 404. Account deletion cascades to its sessions.
Unexpected database failures return a generic 500 rather than a false 404.

New session timestamps are written explicitly in UTC, avoiding database-local
timestamp defaults on a non-UTC host. The mobile completion uses server time.
History contains the planned duration; the summary continues to show the local
active time and cycles, excluding pauses.

## Mobile lifecycle

Guidance begins immediately while registration runs in the background. Finish,
interruption and optional mood writes are serialized against the captured
session. A late registration after leaving is canceled or completed according
to the actual outcome. A failed registration can be retried with its UUID from
the summary, including when the server committed but its response was lost.

Each repository is bound to the API session generation at construction. An old
controller cannot send history or mutations using a replacement account.
Sessions remain on the backend across app bootstrap and repository recreation.
Finished sessions contribute once to the existing meditation count and activity
streak; summary mood is attached to that session, not posted as a dashboard mood.

The retry action is available while the summary is open. This milestone does
not add a durable offline completion outbox or resume an interrupted timer after
process termination.

## Reproducible local checks

```sh
cd elyrii_server
POSTGRES_BINDIR=/opt/homebrew/opt/postgresql@17/bin bun run test:meditation
```

The runner starts disposable PostgreSQL and the actual HTTP API, checks backend
contracts, runs real Dart repositories/controllers, and stops its services. It
does not read a production `.env` or require Kafka or the AI model.

For native verification, use a dedicated booted iOS simulator:

```sh
POSTGRES_BINDIR=/opt/homebrew/opt/postgresql@17/bin \
IOS_SIMULATOR_UDID=<dedicated-udid> \
HOLD_MEDITATION_QA_FRAME=true \
bun run test:meditation
```

The native flow opens the actual library and preview, starts breathing, pauses
and resumes, finishes and saves the summary mood, starts written guidance,
interrupts it, then rebuilds app state and checks persisted history and counts.
The optional hold exposes the connected summary in the simulator browser.
Bootstrap verification is distinct from a force-kill/relaunch or physical-device
test.

## Verification on 2026-11-10

- Flutter analysis: no issues. Full Flutter suite: 515 passed; five opt-in
  connected checks skipped by default. The focused meditation suite passed all
  29 checks, including nested navigation while cancellation is pending.
- Meditation runner: seven backend HTTP/database checks, one real Dart flow and
  one native iOS flow passed against disposable local PostgreSQL/API.
- The Dart flow deliberately loses real committed start/completion responses,
  then verifies safe retries, summary mood, late interruption and account fences.
- The final native rerun passed after the navigation fix. The simulator browser
  showed the completed breathing summary with its saved mood selected. Tests also
  confirmed written-session cancellation, restored history and one completed
  session in backend stats.
- Baseline auth/profile/mood/journal API regression: 13 checks passed. Backend
  TypeScript validation and build passed; the default Bun suite passed 32 checks
  with 121 opt-in checks skipped.
- Test services, mirror and the dedicated iPhone 18 Pro simulator (iOS 27) were
  stopped after verification; disposable database data was removed.

This evidence covers local integration and simulator behavior. Deployed services
and physical devices were not exercised.
