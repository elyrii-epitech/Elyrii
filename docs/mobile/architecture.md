# Elyrii Mobile Application Architecture

## Overview

The Elyrii mobile app is a feature-first Flutter application. Shared code lives
in `core/`, while screens, providers, models, and repositories are grouped under
`features/`.

The app uses `provider` for dependency injection and state management, a
centralized HTTP client for the backend gateway, and a Liquid Glass UI system
that adapts its visual effects to device capability.

## Current Structure

```text
elyrii_app/lib/
+-- main.dart
+-- core/
|   +-- config/       # API URLs, constants, 3D mascot config
|   +-- network/      # ApiClient, ApiException
|   +-- services/     # storage, theme, glass performance, 3D mascot
|   +-- theme/        # colors, dimensions, text styles, ThemeData
|   +-- utils/        # responsive helpers
|   +-- widgets/      # global widgets and Liquid Glass components
+-- features/
|   +-- auth/
|   +-- chatbot/
|   +-- coach/
|   +-- dashboard/
|   +-- gamification/
|   +-- journal/
|   +-- mascot/
|   +-- meditation/
|   +-- settings/
+-- routes/
    +-- app_routes.dart
    +-- home_navigation.dart
    +-- route_generator.dart
```

## Layers

### Presentation

The presentation layer contains Flutter pages, widgets, and providers.

Examples:
- `features/auth/presentation/pages/login_page.dart`
- `features/journal/presentation/widgets/journal_editor_sheet.dart`
- `features/gamification/presentation/providers/gamification_provider.dart`
- `core/widgets/glass/liquid_glass_*.dart`

### Data

The data layer contains models and repositories that either talk to the backend
or provide local data.

Examples:
- `AuthRepository` calls `/auth/login`, `/auth/register`, and `/auth/logout`.
- `JournalRepository` handles CRUD for `/journal`.
- `GamificationRepository` handles `/challenge/*`.
- `UserRepository` handles `/user/me`.
- `CoachRepository` still provides local advice and activities.

Some files are still placeholders (`TempPage`) in `dashboard`, `meditation`, or
`mascot`; the real behavior currently lives in pages and providers.

### Core

The `core/` layer contains:
- runtime and API configuration;
- HTTP client with Bearer token support;
- secure storage;
- theme and design tokens;
- Liquid Glass components;
- 3D mascot viewer;
- global error boundary;
- responsive helpers.

## Initialization

`main.dart` initializes services before `runApp`:

```dart
AppConfig.initialize();

final secureStorage = SecureStorageService();
final apiClient = ApiClient(storage: secureStorage);
final themeProvider = ThemeProvider();
final performanceService = GlassPerformanceService();

await Future.wait([themeProvider.init(), performanceService.init()]);
```

Current global providers:
- `ThemeProvider`
- `GlassPerformanceService`
- `AuthProvider`
- `JournalProvider`
- `ChatbotProvider`
- `GamificationProvider`
- `UserProvider`
- `MascotProvider`
- `DashboardProvider`

`CoachProvider` is created locally inside `CoachPage`.

## Backend Configuration

All endpoint URLs go through `ApiConfig` and the backend gateway.

The base URL is configured by `AppConfig.initialize()`:

```dart
static void initialize({String? gatewayUrl}) {
  final dartDefine = const String.fromEnvironment('BASE_URL');
  ApiConfig.setBaseUrl(
    gatewayUrl ?? (dartDefine.isNotEmpty ? dartDefine : _defaultGatewayUrl),
  );
}
```

Default resolution:
- Web: `http://localhost:3000`
- Android emulator: `http://10.0.2.2:3000`
- iOS, macOS, Linux, Windows: `http://localhost:3000`

Runtime override:

```bash
flutter run --dart-define=BASE_URL=http://192.168.1.20:3000
```

## Consumed Endpoints

```text
Auth
  POST /auth/login
  POST /auth/register
  POST /auth/logout
  POST /auth/refresh

User
  GET /user/me
  PUT /user/me
  GET /user/stats
  POST /user/mood
  GET /user/mood/latest

Journal
  GET /journal
  POST /journal
  GET /journal/:id
  PUT /journal/:id
  DELETE /journal/:id

Challenge
  GET /challenge/available
  POST /challenge/available/:id/start
  GET /challenge/active
  GET /challenge/completed
  GET /challenge/proposals
  POST /challenge/proposals/:id/accept
  POST /challenge/proposals/:id/reject

Chat
  WS /chat/ws?userId=:userId
```

`ApiClient.checkHealth()` also checks gateway, auth, journal, user, chat, and
quest health endpoints at startup without blocking the app.

## Navigation

Navigation is centralized in `RouteGenerator`.

Current routes:
- `/` -> `HomeNavigation`
- `/dashboard`
- `/challenges`
- `/journal`
- `/coach`
- `/meditation`
- `/chatbot`
- `/mascot-customization`
- `/settings`
- `/login`
- `/register`

The initial route depends on `AuthProvider.isAuthenticated`:
- authenticated user: `AppRoutes.home`;
- otherwise: `AppRoutes.login`.

`HomeNavigation` lazy-loads the main pages:
- Home / Dashboard
- Jardin / Challenges
- Journal
- Meditation
- Coach
- Chatbot through a separate bubble button

The mascot customization button is a global overlay in the top-left corner of
the main navigation.

## Data Flows

### Authentication

```text
Login/Register page
  -> AuthProvider
  -> AuthRepository
  -> ApiClient
  -> Gateway /auth/*
  -> SecureStorageService.saveAccessToken()
  -> SecureStorageService.saveUserId()
  -> route /
```

On startup, `AuthProvider.checkAuthStatus()` checks whether an access token
exists. If it does, the app considers the session authenticated and attempts to
fetch the profile through `/user/me`.

Note: `/auth/refresh` is configured, but automatic token refresh is not wired
into `ApiClient` yet.

### Journal

```text
JournalPage
  -> JournalProvider
  -> JournalRepository
  -> ApiClient
  -> /journal
```

The provider keeps the list in memory, sorts it locally by newest/oldest, and
updates it after create, update, or delete operations.

### Chatbot

```text
ChatbotPage
  -> ChatbotProvider.connect()
  -> SecureStorageService.getUserId()
  -> WebSocket.connect(ApiConfig.chatWsUrl(userId))
  -> local in-memory messages
```

Chat history is local to the current app session. The provider exposes
connection state, typing state, and minimized mascot mode.

### Gamification

```text
ChallengesPage
  -> GamificationProvider.loadAll()
  -> Future.wait([
       available,
       active,
       completed,
       proposals
     ])
```

AI proposals can be accepted or rejected. System challenges can be started and
then tracked in the "En cours" section.

### Dashboard

```text
DashboardPage
  -> DashboardProvider.loadDashboardData()
  -> GET /user/mood/latest
  -> GET /user/stats
```

Selecting a mood calls `POST /user/mood`, then reloads user stats.

## Error Handling

The network client throws `ApiException` for non-2xx HTTP responses:

```dart
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic body;
}
```

Unhandled UI errors are wrapped by `GlobalErrorBoundary`, installed through
`MaterialApp.builder`. Providers generally expose an `error` field and reset
`isLoading` to `false` on failure.

## Storage

`SecureStorageService` stores:
- `access_token`
- `refresh_token`
- `user_id`

It uses `flutter_secure_storage` with Keychain on iOS/macOS and secure Android
storage. If macOS Keychain returns `-34018`, it falls back to
`SharedPreferences`, mainly for development and tests.

`SharedPreferences` is also used for:
- theme mode;
- reduced glass effects;
- adaptive blur on scroll;
- mascot theme and cosmetics.

## Performance

Implemented optimizations:
- main pages are lazy-loaded in `HomeNavigation`;
- `GlassPerformanceService` is a singleton with low-end device heuristics;
- blur and transitions can be reduced when visual effects are disabled;
- `RepaintBoundary` is used around the 3D viewer;
- PNG fallback for the 3D mascot on error or widget tests;
- journal list animations are limited to the first items;
- `RefreshIndicator` and parallel loading for gamification/dashboard.

## Security

Already covered:
- access token in secure storage;
- centralized `Authorization: Bearer <token>` header;
- client-side email and password validation;
- emergency resources and crisis banners in the chatbot;
- local auth data is cleared on logout even if the backend logout call fails.

Needs improvement:
- automatic refresh token handling;
- global session expiration handling on HTTP 401;
- privacy policies connected to settings screens;
- no sensitive logs in production builds;
- TLS outside local development.

## Tests

Current tests:
- `test/widget_test.dart`: boots the app with main providers;
- `test/core/services/secure_storage_service_test.dart`: tokens, user id,
  cleanup, and storage availability;
- `test/features/gamification/presentation/pages/challenges_page_test.dart`:
  renders the Jardin page without embedded mascot customization.

Commands:

```bash
cd elyrii_app
flutter test
flutter analyze
dart format --set-exit-if-changed .
```
