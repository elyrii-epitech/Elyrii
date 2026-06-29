# Elyrii Mobile Development

Development guide for `elyrii_app`.

## Prerequisites

- Flutter SDK `>= 3.38.4`
- Dart SDK `>= 3.10.3 < 4.0.0`
- Android Studio for Android
- Xcode for iOS on macOS
- CocoaPods for iOS
- VS Code or Android Studio

CI is pinned to Flutter `3.38.4`. Locally, `flutter --version` may be newer as
long as `flutter pub get`, `flutter analyze`, and `flutter test` remain valid.

## Installation

```bash
git clone https://github.com/elyrii-epitech/Elyrii.git
cd Elyrii/elyrii_app
flutter pub get
flutter doctor
```

## Backend Configuration

By default, the app points to the backend gateway on port `3000`.

Automatic resolution:
- Android emulator: `http://10.0.2.2:3000`
- Web: `http://localhost:3000`
- iOS simulator and desktop: `http://localhost:3000`

To target a specific backend:

```bash
flutter run --dart-define=BASE_URL=http://192.168.1.20:3000
```

The app reads the `BASE_URL` variable.

## Running the App

```bash
cd elyrii_app

# List devices
flutter devices

# Android
flutter run -d android

# iOS
flutter run -d ios

# Web
flutter run -d chrome

# With a specific backend
flutter run -d android --dart-define=BASE_URL=http://10.0.2.2:3000
```

During `flutter run`:
- `r`: hot reload;
- `R`: hot restart;
- `q`: quit.

## Platforms

### Android

Current config in `android/app/build.gradle`:
- `compileSdk = 36`
- `targetSdk = 36`
- `minSdkVersion flutter.minSdkVersion`
- `applicationId = "com.example.elyrii_app"` must be replaced before release;
- release currently uses the debug signing config.

Builds:

```bash
flutter build apk --release
flutter build apk --release --split-per-abi
flutter build appbundle --release
```

### iOS

Current config:
- `IPHONEOS_DEPLOYMENT_TARGET = 15.0`
- CI build without code signing.

Commands:

```bash
cd ios
pod install
cd ..

flutter build ios --release
flutter build ios --release --no-codesign
```

### Desktop and Web

Flutter folders for `web`, `macos`, `linux`, and `windows` exist. The main
product target is mobile, but these targets can be useful for quick tests.

```bash
flutter run -d chrome
flutter build web --release
```

## Quality

Local commands before pushing:

```bash
cd elyrii_app
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Command with automatic formatting:

```bash
cd elyrii_app
dart format .
flutter analyze
flutter test
```

## Current Tests

```text
test/
+-- widget_test.dart
+-- core/services/secure_storage_service_test.dart
+-- features/gamification/presentation/pages/challenges_page_test.dart
```

Current coverage:
- booting `MaterialApp` with part of the provider tree;
- secure storage: tokens, user id, cleanup;
- Jardin page: header and no embedded mascot customization button.

## Feature Structure

Target structure:

```text
feature_name/
+-- data/
|   +-- models/
|   +-- repositories/
+-- presentation/
    +-- pages/
    +-- providers/
    +-- widgets/
```

Complete examples:
- `auth`
- `journal`
- `gamification`
- `chatbot`
- `mascot`

Some features still have placeholder files in `data/`:
- `dashboard`
- `meditation`
- some `mascot` files

Do not document those placeholders as functional APIs.

## Adding a Feature

1. Create `lib/features/<name>/`.
2. Add models and repositories if the feature talks to the backend.
3. Add a `ChangeNotifier` provider if shared state is needed.
4. Add pages and widgets under `presentation/`.
5. Add the route to `routes/app_routes.dart`.
6. Register the route in `RouteGenerator`.
7. Add the provider to `main.dart` if state must be global.
8. Add at least one targeted test for critical behavior.
9. Update `docs/mobile`.

## Network

Use `ApiClient` instead of direct `http` calls.

```dart
final response = await _client.get(ApiConfig.userMeUrl);
```

`ApiClient` handles:
- JSON headers;
- Bearer token from `SecureStorageService`;
- query parameters;
- 30-second timeout;
- JSON parsing;
- `ApiException` for non-2xx HTTP responses;
- debug logs;
- health checks.

For WebSockets, the chatbot uses `dart:io WebSocket`.

## Storage

Use:
- `SecureStorageService` for tokens and sensitive identifiers;
- `SharedPreferences` for UI preferences or non-sensitive customization.

Do not store sensitive journal or chat content in plain text on mobile without an
explicit product decision.

## Theme and UI Components

Use these first:
- `AppColors`
- `AppDimensions`
- `AppTextStyles`
- `LiquidGlass*` components

Example:

```dart
LiquidGlassButton(
  label: 'Se connecter',
  isExpanded: true,
  onPressed: _handleLogin,
)
```

## 3D Mascot

The standard component is `Mascot3DViewer`.

```dart
const Mascot3DViewer(
  config: Mascot3DConfig.authPage(),
  width: 250,
  height: 250,
)
```

Best practices:
- keep a PNG fallback;
- avoid enabling touch interactions without a clear need;
- test pages with widget tests, where the viewer falls back automatically;
- declare every new GLB in `pubspec.yaml`.

## Assets

Adding an asset:

1. Put the file under `elyrii_app/assets/`.
2. Declare the file or folder in `pubspec.yaml`.
3. Run `flutter pub get`.
4. Test on Android and iOS if the asset is native or large.

Important existing assets:
- `assets/icon.png`
- `assets/icon_black_bg.png`
- `assets/mascotte.png`
- `assets/animations/`
- `assets/*.glb`

## Splash and Launcher Icons

Regenerate splash:

```bash
dart run flutter_native_splash:create
```

Regenerate launcher icons:

```bash
dart run flutter_launcher_icons
```

## Debugging

DevTools:

```bash
flutter pub global activate devtools
flutter pub global run devtools
```

Verbose mode:

```bash
flutter run --debug --verbose
```

Common cleanup:

```bash
flutter clean
flutter pub get
```

Android clean:

```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

iOS pods:

```bash
cd ios
pod deintegrate
pod install
cd ..
```

## Production Builds

Obfuscated Android:

```bash
flutter build apk --release \
  --obfuscate \
  --split-debug-info=build/debug-info
```

iOS without signing for verification:

```bash
flutter build ios --release --no-codesign
```

## Release Checklist

- Replace `applicationId = "com.example.elyrii_app"`.
- Add a real Android release signing configuration.
- Wire global HTTP 401 handling and refresh token flow.
- Make sure production `BASE_URL` is provided by CI/CD or a flavor.
- Verify privacy policy and terms of use flows.
- Audit debug logs to avoid sensitive data exposure.
