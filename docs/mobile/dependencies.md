# Flutter Dependencies

This page is aligned with `elyrii_app/pubspec.yaml`.

## Environment

```yaml
environment:
  sdk: ">=3.10.3 <4.0.0"
  flutter: ">=3.38.4"
```

GitHub Actions CI uses Flutter `3.38.4` stable. Local machines may use a newer
stable version as long as the constraints above are respected.

## Production Dependencies

### Flutter SDK

#### flutter

Main SDK for the application.

**Usage:** widgets, Material 3 rendering, navigation, basic animations, platform
integration.

### UI and Assets

#### cupertino_icons (^1.0.9)

Standard iOS icons.

**Usage:** available for components that should follow iOS conventions.

#### iconsax (^0.0.8)

Additional icon pack.

**Usage:** modern business icons, alongside Flutter `Icons`.

#### google_fonts (^8.1.0)

Poppins font loading.

**Usage:** `AppTextStyles` builds styles from `GoogleFonts.poppins()`.

#### flutter_launcher_icons (^0.14.4)

Application icon generation.

**Config:** source `assets/icon_black_bg.png`, Android + iOS.

#### flutter_staggered_grid_view (^0.7.0)

Advanced grid layouts.

**Usage:** available for badge, collection, and non-uniform gamification
layouts. The current code mostly uses standard Flutter grids, but the dependency
remains available for gamification layouts.

### Animations

#### flutter_animate (^4.5.2)

Declarative animations through widget extensions.

**Usage:** auth, coach, gamification, journal, meditation.

#### shimmer (^3.0.0)

Loading effects.

**Usage:** 3D mascot viewer loading state.

#### lottie (^3.3.3)

Lottie JSON animation playback.

**Current assets:**
- `assets/animations/breath.json`
- `assets/animations/Coucou.json`

### 3D

#### flutter_3d_controller (^2.3.0)

Viewer and controller for GLB 3D models.

**Usage:**
- `Mascot3DViewer`;
- auth pages;
- chatbot;
- mascot customization.

**Current GLB assets:**
- `assets/base_basic_design.glb`
- `assets/base_basic_shaded.glb`
- `assets/base_basic_shaded_v3.glb`
- `assets/custom1.glb`

### Network

#### http (^1.6.0)

Dart HTTP client.

**Usage:** `ApiClient` centralizes `GET`, `POST`, `PUT`, `DELETE`, JSON headers,
Bearer token injection, and the 30-second timeout.

The chatbot does not use `http`; it uses `dart:io WebSocket`.

### State Management

#### provider (^6.1.5+1)

State management through `ChangeNotifier`.

**Current global providers:**
- `ThemeProvider`
- `GlassPerformanceService`
- `AuthProvider`
- `JournalProvider`
- `ChatbotProvider`
- `GamificationProvider`
- `UserProvider`
- `MascotProvider`
- `DashboardProvider`

### Storage

#### shared_preferences (^2.5.5)

Local unencrypted key-value storage.

**Usage:**
- theme;
- Liquid Glass preferences;
- mascot customization;
- macOS fallback for secure storage in development/tests.

#### flutter_secure_storage (^10.3.1)

Secure storage for sensitive data.

**Usage:**
- access token;
- refresh token;
- user id.

**Details:** iOS/macOS Keychain and secure Android storage. The service handles
a `SharedPreferences` fallback if macOS Keychain returns `-34018`.

### Date and Internationalization

#### intl (^0.20.2)

Date, number, and i18n formatting.

**Usage:** available for journal dates, stats, and future localization work.

### Accessibility

#### flutter_tts (^4.2.5)

Text-to-Speech through native engines.

**Current usage:** dependency available, not yet wired into a dedicated UI
service.

### Utilities

#### uuid (^4.5.3)

Unique ID generation.

**Usage:** local `ChatMessage` IDs.

#### email_validator (^3.0.0)

Client-side email validation.

**Usage:** login and registration.

#### characters (^1.4.0)

Unicode grapheme manipulation.

**Usage:** safe truncation of challenge descriptions through
`description.characters`.

## Development Dependencies

### flutter_test

Flutter test SDK.

**Usage:** widget tests and unit tests.

### flutter_lints (^6.0.0)

Official Flutter lint rules.

**Config:** `analysis_options.yaml` also enables:
- `prefer_const_constructors`
- `prefer_final_fields`
- `always_declare_return_types`
- `avoid_print`
- `curly_braces_in_flow_control_structures`

### flutter_native_splash (^2.4.7)

Native splash screen generation.

**Config:** `flutter_native_splash.yaml`.

## Declared Assets

```yaml
flutter:
  assets:
    - assets/mascotte.png
    - assets/mascotte_eyes_closed.png
    - assets/animations/
    - assets/base_basic_design.glb
    - assets/base_basic_shaded.glb
    - assets/base_basic_shaded_v3.glb
    - assets/custom1.glb
    - assets/mascot_design_texture.png
    - assets/shaded_painted.png
```

## Summary by Category

| Category | Packages |
| --- | --- |
| UI | `cupertino_icons`, `iconsax`, `google_fonts`, `flutter_launcher_icons` |
| Animations | `flutter_animate`, `shimmer`, `lottie` |
| 3D | `flutter_3d_controller` |
| Layout | `flutter_staggered_grid_view` |
| Network | `http` |
| State | `provider` |
| Storage | `shared_preferences`, `flutter_secure_storage` |
| I18n/date | `intl` |
| Accessibility | `flutter_tts` |
| Utilities | `uuid`, `email_validator`, `characters` |
| Quality | `flutter_test`, `flutter_lints`, `flutter_native_splash` |

## Platforms

The project contains generated Flutter folders for:
- Android;
- iOS;
- Web;
- macOS;
- Linux;
- Windows.

The main mobile experience targets Android and iOS. Desktop and web targets are
mainly useful for development and cross-platform verification.

## Useful Commands

```bash
cd elyrii_app

# Install dependencies
flutter pub get

# Check available updates
flutter pub outdated

# Upgrade within existing constraints
flutter pub upgrade

# Propose major upgrades
flutter pub upgrade --major-versions
```
