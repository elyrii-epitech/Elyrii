# New frontend: auth, profile and mood integration

Branch: `feature/rafael-sapalo/frontend-backend-integration`, based on
`cleanup/frontend-dev-pr` at `bc31546`. Work stays local until an explicit push.
The new screens, visual assets, navigation and onboarding design are retained.

## Included contracts

- Register/login return `token` and rotating `refreshToken` in JSON. Cookie
  support remains available to existing clients.
- Signup matches the displayed frontend rules: eight or more characters,
  one capital letter and one digit (server maximum: 128).
- Tokens remain in Keychain/Keystore. Expired restored sessions can refresh;
  concurrent requests share one refresh. A 401 can replay an authenticated
  request once. Network failures never replay writes.
- Logout clears local state immediately, then attempts server revocation with
  the captured credentials. A late refresh cannot revive an old session.
- Profile reads/edits use `GET/PUT /user/me`. Concurrent first-launch settings
  initialization no longer races the unique user settings row.
- Mood writes use `POST /user/mood` with `verySad`, `sad`, `neutral`, `happy`
  or `veryHappy`. Latest mood and dashboard reads are account scoped.
- Password recovery uses `POST /auth/password-reset/request` and
  `POST /auth/password-reset/confirm`. Recovery codes are hashed, expire after
  15 minutes, and can be consumed once. Recovery requires a 12–128 character
  new password and revokes existing refresh credentials.

## Local configuration and testing

The API and mobile default to port `3000`. An iOS simulator uses `localhost`,
Android Emulator uses `10.0.2.2`; a physical device requires a reachable gateway.
Override the target explicitly:

```sh
cd elyrii_app
flutter run --dart-define=ELYRII_ENV=development \
  --dart-define=ELYRII_API_URL=http://127.0.0.1:3188
```

The connected runner starts its own local PostgreSQL cluster and API, executes
the real HTTP contracts and Dart providers, and stops both services on exit.
It requires PostgreSQL binaries, Bun and Flutter dependencies already installed:

```sh
cd elyrii_server
POSTGRES_BINDIR=/opt/homebrew/opt/postgresql@17/bin bun run test:auth-profile-mood
```

Set `MOBILE_TEST_API_PORT` / `MOBILE_TEST_DB_PORT` if the default test ports
3188 / 15448 are occupied. A supplied `IOS_SIMULATOR_UDID` additionally runs
the actual new iOS login/onboarding and restart test. It must be a dedicated,
already-booted test simulator; this test clears its Elyrii test credentials.

The shared fixture now also runs the [journal integration](frontend-journal.md).
It uses the baseline schema, the existing user context generation column, and
the recovery and journal migrations. It does not validate the pgvector/AI migration chain.
Run the existing `scripts/test-context-db.sh` suite separately for that chain.
Do not point these fixture tests at a shared development or production database.

## Activation and mail

Production always requires email verification. Set `PUBLIC_URL` to the public
HTTPS API origin and configure `EMAIL_VERIFICATION_MAIL_WEBHOOK` plus
`EMAIL_VERIFICATION_MAIL_SECRET`. The mail provider receives an
`email-verification` template with `to`, `verificationUrl` and
`expiresInMinutes`. Activation links use a fragment token, consumed by the
confirmation page through POST; the token never needs to appear in access logs.

Recovery requires `PASSWORD_RESET_MAIL_WEBHOOK` and
`PASSWORD_RESET_MAIL_SECRET`; its template is `password-reset`, with `to`,
`code` and `expiresInMinutes`. The activation sender can use the recovery
configuration as a fallback. Webhooks require HTTPS and reject redirects.
No real email is sent by these tests. Unconfigured mail returns an unavailable
response instead of claiming successful delivery.

## Database and release boundary

Migration `0006_native_auth_recovery.sql` adds only the recovery-token table.
The cleanup branch's AI/context migrations and schema fields are preserved.
Apply the normal ordered migrations with `bun run db:migrate` on an appropriate
staging database; do not substitute the test fixture for deployment migrations.
Release builds still require explicit HTTPS `ELYRII_API_URL`.

This auth milestone does not finish chat/Kafka integration,
challenge/meditation contracts, reports/export, or cross-device Parcours progress.
Journal pagination and persistence are covered by the subsequent journal milestone.
Chat and Kafka contracts are covered by the subsequent [chat milestone](frontend-chat.md).
Challenge progression and the garden are covered by the [challenges milestone](frontend-challenges.md).
Practice registration, completion and history are covered by the [meditation milestone](frontend-meditation.md).
Guided programs and account-synced progress are covered by the [Coach milestone](frontend-coach.md).
Preferences, account export and settings actions are covered by the [settings milestone](frontend-settings.md).
It neither deploys a backend nor publishes a mobile build.

## Verification on 10 November 2026

- Flutter analysis: no issues; TypeScript checking and Bun build succeeded.
- Flutter suite: 504 passed, one opt-in connected test skipped in the ordinary
  suite and then passed separately against the real local API.
- Backend default suite: 29 passed, 86 opt-in database/AI cases skipped.
- Disposable PostgreSQL runner: eight connected backend cases and the real
  Dart auth/profile/mood provider flow passed.
- Dedicated iOS 27 simulator: the actual new login and onboarding screens saved
  the name, goal and mood, then a fresh app bootstrap restored the native session
  and recovered the name and mood. This was not a demo session.
- No production database, deployed API, real mail delivery or physical device
  was used. Temporary test services and the dedicated simulator were removed
  or stopped afterward.
