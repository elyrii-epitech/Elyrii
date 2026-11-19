# Challenges integration with the new frontend

Branch: `feature/rafael-sapalo/frontend-backend-integration`, based on
`cleanup/frontend-dev-pr`. The existing challenge cards, action buttons,
progress indicators, monthly garden, flower details and navigation are retained.
A transparent Material surface fixes the native expandable-list ink assertion
without changing layout, spacing or colors.
The dashboard answer keeps its existing fade, with distinct outgoing animation
keys so a quickly restored or rolled-back mood cannot trigger a duplicate-key
assertion while advancing challenge activity.

## Connected behavior

- The catalogue uses account-scoped `/challenge/available`, `/active`,
  `/completed` and `/proposals` reads. The mobile client follows 100-item
  cursor pages instead of silently losing older flowers beyond the first page.
- Paged reads use `pageSize` (1–100) with paired `cursorDate` and `cursorId`.
  Responses are `{items, nextCursor}`; cursors use millisecond precision and ID
  tie-breaks. Existing array responses, limit and sorting remain available
  when `pageSize` is omitted.
- Starting a SYSTEM challenge serializes assignment creation per account.
  Repeated or concurrent starts return the same assignment. Completed
  challenges cannot be restarted for another reward.
- Accept/reject commands use the owned assignment ID. Matching retries are
  idempotent; conflicting transitions return 409 and foreign IDs return 404.
  An AI template cannot be acquired through the public SYSTEM start endpoint.
- Start and accept reconcile existing activity immediately. The existing
  all-time and rolling-period condition semantics remain in place; an account
  that already meets a goal can complete it as soon as it starts.
- Mutation responses include joined template details. Proposal definitions are
  validated against the supported condition types, positive integer targets
  and ALL/ANY aggregation. ANY progress uses the best condition; confirmed
  completed challenges display full progress.

## Progress and rewards

Mood and journal writes reconcile challenge progress before acknowledging the
write. A progress failure preserves the committed mood/note and is retried by
the first active/completed history read. Journal retries count the persisted
note once; edits and deletion refresh still-active conditions.

Progress updates compare the assignment's previous state under account and row
locks. Older work cannot overwrite newer progress or a terminal completion.
Completion, points, the reward marker and the notification commit together.
The existing unique reward ledger prevents a second grant.

The app refreshes challenges after confirmed mood or journal activity, even
inside its normal 30-second cache window. A new account clears old challenge
state; a late command cannot report success in a replacement session. A
completed record takes precedence if parallel list reads overlap a transition.

Account deletion also removes unshared private AI proposal templates. SYSTEM
templates and templates still assigned to another account are retained.

No new database migration is needed for this milestone. The normal migrations
already required by the integration branch still apply; the test fixture is
not a deployment migration recipe.

## Reproducible local checks

```sh
cd elyrii_server
POSTGRES_BINDIR=/opt/homebrew/opt/postgresql@17/bin bun run test:challenges
```

The scoped runner starts disposable PostgreSQL and the real HTTP API, runs the
challenge contracts and real Dart providers, then stops its services. It uses
the same shared fixture as the previous auth/journal milestones. Kafka and the
AI model are not needed: proposal fixtures enter through the authenticated
proposal API. This validates proposal handling, not live AI generation.

To exercise the actual new iOS screens, supply a dedicated booted simulator:

```sh
POSTGRES_BINDIR=/opt/homebrew/opt/postgresql@17/bin \
IOS_SIMULATOR_UDID=<dedicated-udid> \
HOLD_CHALLENGES_QA_FRAME=true \
bun run test:challenges
```

The native flow accepts and rejects proposals, starts a system challenge,
records two moods through the dashboard, checks partial and completed progress,
and rebuilds app state to verify the persisted garden. The optional hold leaves
the garden visible for the simulator browser. This is bootstrap verification,
not a force-kill/relaunch or physical-device test.

The baseline auth/profile/mood and journal regression flow remains available
through `bun run test:auth-profile-mood`.

## Verification on 2026-11-10

- Flutter analysis: no issues. Full Flutter suite: 514 passed, four opt-in
  connected checks skipped by default.
- Challenge runner: eight backend HTTP/database checks, one real Dart provider
  flow and one native iOS flow passed against disposable local PostgreSQL/API.
- Baseline auth/profile/mood/journal runner: 13 backend checks and two real Dart
  flows passed after the shared activity and account-deletion changes.
- Backend TypeScript check and build passed. Default Bun suite: 32 passed,
  112 opt-in integration checks skipped.
- The mood fade regression reproduced the native duplicate-key assertion before
  the fix and passed afterward with animations enabled.
- The simulator browser showed accepted/started challenges, then the restored
  November garden with both completed flowers. The dedicated iPhone 18 Pro
  simulator (iOS 27), mirror and test services were stopped after verification.

These checks cover local integration and simulator behavior. Live AI generation,
deployed services and physical devices were not exercised.
