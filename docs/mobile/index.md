# Elyrii mobile app

The Flutter frontend lives in `elyrii_app`. The supported release targets are
**iOS and Android**. Flutter **3.47.4** is pinned in `.fvmrc`; Dart **3.13.3**
and the dependencies are defined in `pubspec.yaml` and its lockfile.

## Getting started

```bash
cd elyrii_app
flutter pub get --enforce-lockfile
flutter run -d DEVICE_ID
```

In development, the gateway uses port 3001 (`10.0.2.2` on the Android emulator,
`localhost` on the iOS simulator). For a physical phone, provide a reachable
gateway with `--dart-define=ELYRII_API_URL=https://YOUR_GATEWAY`.

## Documentation

| Guide | Contents |
| --- | --- |
| [Development](development.md) | SDK, installation, environment, and native execution |
| [Architecture](architecture.md) | Navigation, sessions, networking, and account-scoped storage |
| [Features](features.md) | Supported flows and their data |
| [UI wording](wording.md) | French vocabulary, tone, and review captures |
| [Design system](design.md) | Theme, shared components, accessibility, and assets |
| [Dependencies](dependencies.md) | Package responsibilities and reproducible inventory |
| [CI/CD](ci-cd.md) | Checks, tests, builds, and artifacts |
| [Release](release.md) | Migration, service configuration, and native validation |
| [Accessibility](accessibility.md) | Automated tests and TalkBack/VoiceOver protocol |
| [Meditation](meditation.md) | Catalog, durations, guidance, and API contract |
| [Customization](mascot-accessories.md) | Wardrobe, progression, and asset rebuilding |
| [Mascot motion](velours-motion.md) | Clips, transitions, and generation |

## Local verification

From the repository root, with the pinned SDK on `PATH`:

```bash
bash scripts/flutter_ci_check.sh
```

Native tests are described in the development guide.

## Entry points

- `elyrii_app/lib/main.dart`: application initialization.
- `elyrii_app/lib/app/app_dependencies.dart`: services and session scope.
- `elyrii_app/lib/app/router/app_router.dart`: routes and navigation.
- `elyrii_app/lib/core/config/api_config.dart`: gateway configuration.
- `elyrii_app/lib/core/network/api_client.dart`: shared REST transport.
- `.github/workflows/flutter-check-and-docs.yml`: validation and API documentation.
