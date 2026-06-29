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
- **Minimum Flutter:** `>= 3.38.4`
- **Dart:** `>= 3.10.3 < 4.0.0`
- **CI Flutter:** `3.38.4` stable
- **Android:** `compileSdk 36`, `targetSdk 36`
- **iOS:** deployment target `15.0`
- **Default backend:** gateway port `3000`
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
flutter pub get
flutter run
```

With a specific backend:

```bash
flutter run --dart-define=BASE_URL=http://localhost:3000
```

Local verification:

```bash
cd elyrii_app
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

## Important Files

- `elyrii_app/lib/main.dart`
- `elyrii_app/lib/core/config/app_config.dart`
- `elyrii_app/lib/core/config/api_config.dart`
- `elyrii_app/lib/core/network/api_client.dart`
- `elyrii_app/lib/routes/home_navigation.dart`
- `elyrii_app/pubspec.yaml`
- `.github/workflows/flutter-build.yml`
- `.github/workflows/flutter-check-and-docs.yml`
