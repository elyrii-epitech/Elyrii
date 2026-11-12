# iOS and Android frontend dependencies

The source of truth is `elyrii_app/pubspec.yaml` and its committed lockfile.
Flutter **3.47.4** / Dart **3.13.3** are used locally and in CI;
`flutter pub get --enforce-lockfile` verifies dependency resolution.

| Dependency | Responsibility |
| --- | --- |
| Flutter, flutter_localizations, intl | UI, declared French locale, and initialized French dates |
| provider, go_router | Feature state/injection and persistent navigation shell |
| http, http_parser | Shared cancellable HTTP transport and file MIME types |
| cross_file | Native photo reading/upload through the picker's `XFile` interface |
| flutter_secure_storage | Account-scoped credentials and content keys, without plaintext fallback |
| cryptography | AES-GCM authenticated against the owner and resource |
| shared_preferences | Preferences without private content, cache freshness, and purge markers |
| sqflite, sqflite_common, path | iOS/Android SQLite, shared interface, and normalized paths |
| sqflite_common_ffi | Development dependency for real SQLite tests on Linux |
| flutter_animate, liquid_glass_widgets | Animations respecting system settings and shared glass primitives |
| flutter_3d_controller 2.3.0, visibility_detector | Existing mascot renderer, visibility-based suspension and release |
| image_picker, image_cropper | Native iOS/Android gallery and cropping |
| path_provider | Private cache directories for avatar copies and temporary exports |
| package_info_plus | Installed version/build number for display and diagnostics |
| share_plus | User-initiated native sharing of exports and diagnostics, with an iPad-compatible origin |
| uuid, url_launcher, cupertino_icons | Correlation/resource IDs, external resources, and icons |
| flutter_test, integration_test, flutter_lints | Unit/widget tests, native integration, and static analysis |
| flutter_launcher_icons, flutter_native_splash | Icon and splash generation from source assets |

Chat transport uses `dart:io` for the Bearer-authenticated WebSocket.
Poppins fonts are bundled; Google Fonts are not downloaded.
The app uses native SQLite, authenticated WebSockets, and image cropping.

Upgrades must pass asset tests, iOS/Android builds, and native flows before merge.

To regenerate the CycloneDX inventory from `elyrii_app`:

```bash
mkdir -p build
flutter pub deps --json > build/pub-deps.json
python3 tool/frontend_sbom.py --deps build/pub-deps.json --output build/frontend.cdx.json
```

Native Gradle/CocoaPods dependency tracking complements this inventory after
building; see the [release guide](release.md).
