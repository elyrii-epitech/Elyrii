# Elyrii Mobile Documentation

Technical documentation for the Flutter app located in `elyrii_app`.

## Overview

Elyrii mobile is a Flutter well-being companion app with:
- authentication through the backend gateway;
- mood and stats dashboard;
- personal journal;
- WebSocket chatbot with emergency resources;
- garden/challenge-based gamification;
- local coach;
- breathing exercises;
- customizable 3D mascot;
- Liquid Glass design system.

## Quick Information

- **App version:** `1.0.0+1`
- **Minimum Flutter:** `3.47.4 (pinned in `.fvmrc`)`
- **Dart:** `>= 3.13.3 < 4.0.0`
- **CI Flutter:** `3.47.4` from `.fvmrc`
- **Android:** `compileSdk 36`, `targetSdk 36`
- **iOS:** deployment target `15.0`
- **Default backend:** development gateway port `3001`
- **Backend override:** `--dart-define=BASE_URL=...`

## Documentation Pages

### [Architecture](architecture.md)

Code structure, providers, navigation, backend flows, storage, and security.

### [Features](features.md)

Current features, with separation between backend-backed behavior, local data,
and placeholders.

### [Design System](design.md)

Theme, colors, typography, Liquid Glass, 3D mascot, animations, and responsive
layout.

### [Dependencies](dependencies.md)

Dependency list aligned with `pubspec.yaml`, versions, and usage rationale.

### [Development](development.md)

Installation, running the app, `BASE_URL` configuration, tests, builds, and best
practices.

### [CI/CD](ci-cd.md)

Flutter GitHub Actions workflows, artifacts, and equivalent local commands.

## Quick Start

```bash
cd elyrii_app
flutter pub get --enforce-lockfile
flutter run
```

With a specific backend:

```bash
flutter run --dart-define=BASE_URL=http://localhost:3001
```

Local verification:

```bash
cd elyrii_app
dart format --output=none --set-exit-if-changed lib test tool integration_test test_driver
flutter analyze
flutter test
```

## Important Files

- `elyrii_app/lib/main.dart`
- `elyrii_app/lib/core/config/app_config.dart`
- `elyrii_app/lib/core/config/api_config.dart`
- `elyrii_app/lib/core/network/api_client.dart`
- `elyrii_app/lib/app/app_dependencies.dart`
- `elyrii_app/lib/app/router/app_router.dart`
- `elyrii_app/pubspec.yaml`
- `.github/workflows/flutter-check-and-docs.yml`

## Frontend audit corrections

The application targets **iOS and Android only**. Its CI and integration tests
cover these native targets; browser and desktop distribution are outside scope.

See [implementation and validation](frontend-audit-implementation.md) for the
23 audit findings and their current treatment.
