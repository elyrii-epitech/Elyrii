# Frontend CI — iOS and Android

The single Flutter workflow is `.github/workflows/flutter-check-and-docs.yml`.
Its name, **Flutter Style, Test & Docs**, is used by API documentation publishing.

The app targets **iOS and Android** only. Pushes and PRs to `frontend`, `dev`,
and `main` trigger checks when Flutter code, mobile documentation, or its CI
changes. Manual execution is also available.

The shared action reads Flutter **3.47.4** from `elyrii_app/.fvmrc`, then enforces
`flutter pub get --enforce-lockfile`. Local validation uses the same SDK and
Dart **3.13.3**.

| Job | Check / artifact |
| --- | --- |
| Frontend quality | Non-mutating formatting check, analysis, unit/widget tests, and LCOV coverage |
| Android technical build | Java 17, development debug APK |
| iOS simulator technical build | Development debug simulator application, macOS runner |
| Frontend Android integration | API 35 emulator, bootstrap, persistence, and navigation with native plugins |
| Frontend iOS integration | Available iPhone simulator on the macOS runner, bootstrap, native persistence, and navigation |
| Frontend API documentation | Pinned Dartdoc 9.0.11, `dartdoc-html` artifact retained for the documentation pipeline |

Builds and integration depend on the quality job. Administrators must configure
branch protections and required checks in GitHub; a workflow file alone does
not enable them.

## Compatibility and native integration

The Android wrapper uses **Gradle 8.14.3**, with Java 17, AGP 8.12.1, and
Kotlin 2.2.20. These meet the minimum versions required by Flutter 3.47.4 and
the installed sharing/version plugins; SDK compatibility checks remain enabled.

Flows wait for the launch screen to finish and scroll controls into view before
tapping, so they work at simulator screen sizes.
A dedicated native scenario verifies encrypted history reopening and purging
with the real SQLite and Keychain/Keystore plugins. It covers SQLite commands
that return a row and require `rawQuery`, even when setting a value such as
`PRAGMA secure_delete = ON`.

## Local commands

From `elyrii_app`, using the SDK version in `.fvmrc`:

```bash
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test tool integration_test
flutter analyze --no-pub
flutter test --no-pub --coverage
flutter build apk --debug --no-pub --dart-define=ELYRII_ENV=development
flutter build ios --simulator --debug --no-pub --dart-define=ELYRII_ENV=development
flutter test integration_test/frontend_flows_test.dart -d DEVICE_ID --dart-define=ELYRII_ENV=development
dart pub global activate dartdoc 9.0.11
dart pub global run dartdoc --output doc/api
```

From the repository root, `bash scripts/flutter_ci_check.sh` runs locked
dependency resolution, the non-mutating format check, analysis, and tests.

On this workstation, check flows in the browser first. Do not start a local
simulator or emulator. A build or installation on a phone requires explicit
authorization after browser review. Native GitHub Actions jobs provide evidence
only after they have run.

## Distribution

A production/staging build requires an explicit HTTPS gateway URL:

```bash
flutter build appbundle --release --dart-define=ELYRII_ENV=production --dart-define=ELYRII_API_URL=https://YOUR_GATEWAY
flutter build ipa --release --dart-define=ELYRII_ENV=production --dart-define=ELYRII_API_URL=https://YOUR_GATEWAY
```

Replace the example with the real URL. Android release signing requires
`android/key.properties` and a distribution keystore; no debug key is used as
a fallback. iOS requires the organization's certificates and provisioning
profiles. Development CI artifacts are not production releases. This CI does
not deploy or submit builds to stores.
