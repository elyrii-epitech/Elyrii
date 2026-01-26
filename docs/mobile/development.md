# Elyrii Mobile Development

Development guide for Flutter mobile application.

## Development environment

### Prerequisites

**Required software:**
- Flutter SDK 3.38.2+
- Dart SDK 3.10.0+
- Android Studio (pour Android)
- Xcode (pour iOS, macOS uniquement)
- VS Code ou Android Studio comme IDE

**Recommended VS Code extensions:**
- Flutter
- Dart
- Error Lens

### Installation

```bash
# Clone the repository
git clone https://github.com/elyrii-epitech/Elyrii.git
cd Elyrii/elyrii_app

# Install dependencies
flutter pub get

# Check installation
flutter doctor
```

## Platform configuration

### Android

**Required SDK:**
- minSdk: 21 (Android 5.0)
- targetSdk: 34 (Android 14)

**Android Studio configuration:**
1. SDK Manager > SDK Platforms > Installer Android 14.0 (API 34)
2. SDK Manager > SDK Tools > Installer Android SDK Build-Tools 34

### iOS

**Required configuration:**
- macOS avec Xcode 15+
- iOS Deployment Target: 13.0+

```bash
cd ios
pod install
cd ..
```

## Launching the application

### Available devices

```bash
# List devices
flutter devices
```

### Launch the app

```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Web
flutter run -d chrome

# Debug mode (default)
flutter run --debug

# Release mode
flutter run --release
```

## Debugging

### Verbose mode

```bash
flutter run --debug --verbose
```

### DevTools

```bash
# Activate DevTools
flutter pub global activate devtools
flutter pub global run devtools
```

### Hot Reload

**During execution:**
- `r` : Hot reload
- `R` : Hot restart (reset state)
- `q` : Quit

### Breakpoints

**VS Code / Android Studio:**
1. Cliquer sur la marge gauche pour ajouter un breakpoint
2. Lancer en mode debug (F5)
3. Use les contrôles de debug

## Production build

### Android

**APK:**
```bash
# Standard APK
flutter build apk --release

# APK split by ABI (recommended)
flutter build apk --release --split-per-abi
```

**App Bundle (Google Play):**
```bash
flutter build appbundle --release
```

**With obfuscation:**
```bash
flutter build apk --release \
  --obfuscate \
  --split-debug-info=build/debug-info
```

### iOS

```bash
# Build iOS
flutter build ios --release

# Without code signing (for test)
flutter build ios --release --no-codesign
```

### Web

```bash
flutter build web --release
```

## Dependency management

### Add a dependency

```bash
# Production
flutter pub add package_name

# Dev only
flutter pub add --dev package_name
```

### Update

```bash
# Minor updates
flutter pub upgrade

# Major updates
flutter pub upgrade --major-versions

# Check available updates
flutter pub outdated
```

### Clean

```bash
flutter clean
flutter pub get
```

## Assets

### Add images

1. Place image in `assets/images/`
2. Declare in `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/images/logo.png
```

### Add Lottie animations

1. Place JSON file in `assets/animations/`
2. Declare in `pubspec.yaml`
3. Use with lottie package

## Code quality

### Linting

```bash
# Analyze code
flutter analyze

# See all warnings
flutter analyze --no-fatal-infos
```

### Formatting

```bash
# Format entire project
dart format .

# Check without modifying
dart format --set-exit-if-changed .
```

### Tests

```bash
# All tests
flutter test

# With coverage
flutter test --coverage
```

## Performance

### Profiling

```bash
# Profile mode
flutter run --profile
```

### Optimizations

**Widgets:**
- Use `const` when possible
- Appropriate keys for lists
- Avoid unnecessary rebuilds

**Images:**
- Use la taille appropriée
- Cache network images
- Optimize assets

## Troubleshooting

### Common problems

**"Target of URI doesn't exist":**
```bash
flutter clean
flutter pub get
```

**"Gradle build failed":**
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

**"Pod install failed" (iOS):**
```bash
cd ios
pod deintegrate
pod install
cd ..
```

**Hot reload not working:**
- Press 'R' (hot restart)
- Restart `flutter run`

## Resources

**Documentation:**
- Flutter: https://flutter.dev/docs
- Dart: https://dart.dev/guides

**Packages:**
- pub.dev: https://pub.dev

**Tools:**
- DevTools: https://docs.flutter.dev/tools/devtools
