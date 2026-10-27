# iOS and Android frontend development

The only release targets are **iOS and Android**. Use Flutter **3.47.4** /
Dart **3.13.3**, defined in `elyrii_app/.fvmrc`. With FVM, run `fvm install`,
then `fvm flutter …`. Otherwise, install this exact version and add its `bin`
directory to `PATH`.

```bash
cd elyrii_app
flutter --version
flutter pub get --enforce-lockfile
flutter doctor -v
flutter run -d DEVICE_ID
```

In debug mode, the default environment is `development`, with the gateway on
port **3001**. The Android emulator uses `10.0.2.2`; the iOS simulator uses
`localhost`. On a physical phone, use a reachable HTTPS gateway:

```bash
flutter run -d DEVICE_ID --dart-define=ELYRII_API_URL=https://YOUR_DEVELOPMENT_GATEWAY
```

`ELYRII_API_PORT` changes the local development port. The legacy `BASE_URL`
argument is still accepted. Staging/production require an explicit HTTPS URL
without embedded credentials or a loopback address. A release build without an
environment argument selects production; it does not silently target the local
development gateway.

Android/iOS allow HTTP only for local renderer and development exceptions.
The Android application ID is `com.elyrii.elyrii_app`; release signing requires
`android/key.properties`. Do not commit credentials. The iOS CI target is a
debug simulator application.

## Architecture and tests

Register shared services in `lib/app/app_dependencies.dart`. Account-scoped
operations capture a session revision. Repositories validate external JSON
through `decodeResponse` / `decodeListResponse` and restrict offline fallbacks
to explicitly supported typed errors. A 401, an invalid response, or a rejected
mutation must not become a cached success. Garden challenges and wardrobe
unlocks reset on account changes, entry into demo mode, and logout.

Journal entries/drafts and chat messages/titles use SQLite and AES-GCM. Keys
are stored in Keychain/Keystore. The test adapter injects SQLite FFI; this does
not replace plugin verification on iOS/Android. Chat retains the native Bearer
header; the required server contract must be delivered separately.

Use the shared accessible controls for labels, keyboard access, and reduced
motion. Build unbounded histories with lazy slivers. For Flutter Animate, use
`animateRespectingMotion(context)`.

Pre-merge commands are listed in [CI/CD](ci-cd.md). Tests cover session races,
credentials, encrypted storage, purge/recovery, journal entries, out-of-order
preferences, network cancellation/timeouts, chat, session clocks/lifecycle,
routes, bootstrap, accessibility, and large lists.

## Native integration

```bash
flutter test integration_test/frontend_flows_test.dart -d DEVICE_ID --dart-define=ELYRII_ENV=development
```

Also check gallery access/upload, renderer release, TalkBack/VoiceOver, and
enlarged text on representative devices.

See the [release guide](release.md) for migrations and device/gateway checks,
and the [accessibility protocol](accessibility.md) for assistive technology flows.
