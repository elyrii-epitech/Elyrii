# Elyrii Mobile CI/CD

Mobile workflows live in `.github/workflows/`.

## Flutter Workflows

### `flutter-build.yml`

GitHub Actions name: `Flutter Build & Test`

Triggers:
- push to `main` or `dev`;
- pull request to `main` or `dev`.

Jobs:
- `build-android` on `ubuntu-latest`;
- `build-ios` on `macos-latest`.

Common steps:
1. checkout;
2. install Flutter `3.38.4` stable;
3. cache `~/.pub-cache` and `elyrii_app/.dart_tool`;
4. `flutter pub get`;
5. `flutter analyze`;
6. `flutter test`.

Android steps:
- `flutter build apk --release`;
- upload artifact `app-android-apk`.

iOS steps:
- `flutter build ios --no-codesign`;
- upload artifact `app-ios-build`.

### `flutter-check-and-docs.yml`

GitHub Actions name: `Flutter Style, Test & Docs`

Triggers:
- push to `main` or `dev`;
- pull request to `main` or `dev`.

Job:
- `check` on `ubuntu-latest`.

Steps:
1. checkout;
2. install Flutter `3.38.4` stable;
3. cache dependencies;
4. `flutter pub get`;
5. `dart format --set-exit-if-changed .`;
6. `flutter analyze`;
7. `flutter test`;
8. generate Dartdoc;
9. upload artifact `dartdoc-html`.

## Main Documentation

`build-and-deploy-docs.yml` assembles the main MkDocs documentation. It retrieves
the mobile `dartdoc-html` artifact and copies it into `docs/mobile/api`.

If the artifact is not available, the workflow creates a placeholder
`docs/mobile/api/index.md` so MkDocs can continue.

## CI Flutter Version

```yaml
flutter-version: '3.38.4'
channel: 'stable'
```

This version must remain compatible with:

```yaml
environment:
  sdk: ">=3.10.3 <4.0.0"
  flutter: ">=3.38.4"
```

## Equivalent Local Commands

```bash
cd elyrii_app
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --release
```

To test Dartdoc generation:

```bash
cd elyrii_app
flutter pub global activate dartdoc
flutter pub global run dartdoc
```

## Artifacts

| Workflow | Artifact | Contents |
| --- | --- | --- |
| `flutter-build.yml` | `app-android-apk` | Android release APK |
| `flutter-build.yml` | `app-ios-build` | iOS build without code signing |
| `flutter-check-and-docs.yml` | `dartdoc-html` | Dartdoc documentation |

## Common Fixes

### Formatting

```bash
cd elyrii_app
dart format .
```

### Static Analysis

```bash
cd elyrii_app
flutter analyze
```

### Tests

```bash
cd elyrii_app
flutter test
```

### Dependencies

```bash
cd elyrii_app
flutter clean
flutter pub get
```

## Current Limitations

- No automated Play Store/App Store publishing.
- No dedicated Android release signing config in the repository.
- CI iOS build runs without code signing.
- No separate Flutter flavors for dev/staging/prod.
- `BASE_URL` must be provided with `--dart-define` at runtime or build time if
  the target does not use local defaults.
