# Elyrii Mobile Application Architecture

## Overview

The Elyrii mobile application follows a modular feature-first architecture, with clear separation between core code (shared) and features (independent functional modules).

## Architecture diagram

```
┌─────────────────────────────────────────┐
│           Presentation Layer            │
│  (Screens, Widgets, State Management)   │
└──────────────┬──────────────────────────┘
               │
┌──────────────┴──────────────────────────┐
│           Features Layer                │
│  (Business Logic, Use Cases, Models)    │
└──────────────┬──────────────────────────┘
               │
┌──────────────┴──────────────────────────┐
│            Core Layer                   │
│   (Services, Utils, Network, Theme)     │
└──────────────┬──────────────────────────┘
               │
┌──────────────┴──────────────────────────┐
│         External Dependencies           │
│    (Flutter SDK, Packages, Platform)    │
└─────────────────────────────────────────┘
```

## Application layers

### 1. Presentation Layer

Responsible for user interface and user interaction.

**Components:**
- Screens: Application pages
- Widgets: Components UI réutilisables
- State Management: Provider for state management

**Responsibilities:**
- Data display
- User interaction handling
- Navigation between screens
- Animations and transitions

### 2. Features Layer

Contains business logic organized by feature.

**Current features:**
- Auth: Authentication and session management
- Chatbot: Conversation with AI
- Coach: Personalized guidance
- Dashboard: Main dashboard
- Gamification: Quests and rewards
- Journal: Personal journal
- Mascot: Interactive mascot
- Meditation: Guided meditation
- Notifications: Notification management
- Settings: Settings and preferences

**Typical feature structure:**
```
feature_name/
├── models/          # Data models
├── screens/         # Feature screens
├── widgets/         # Specific widgets
├── providers/       # State management (if needed)
└── services/        # Business services (if needed)
```

### 3. Core Layer

Shared code between all features.

**Modules:**

**Config**
- Application configuration
- Global constants
- API endpoints
- Animation configuration

**Services**
- ThemeProvider: Theme management
- GlassPerformanceService: Performance optimization
- Network services
- Storage services

**Theme**
- Theme definition (light/dark)
- Reusable styles
- Color palette
- Typography

**Widgets**
- Components réutilisables
- Boutons personnalisés
- Cards
- Loaders et indicateurs

**Network**
- HTTP client
- Interceptors
- Network error handling

**Utils**
- Utility functions
- Extensions
- Helpers

**Errors**
- Centralized error handling
- Error messages
- Error handling

## Design patterns

### State Management: Provider

L'application utilise Provider for state management:

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: themeProvider),
    ChangeNotifierProvider.value(value: performanceService),
  ],
  child: MyApp(),
)
```

**Advantages:**
- Simple to use
- Optimal performance
- Well integrated with Flutter
- Testable

### Navigation: Named Routes

Routing system based on named routes:

```dart
MaterialApp(
  initialRoute: AppRoutes.login,
  onGenerateRoute: RouteGenerator.generateRoute,
)
```

**Advantages:**
- Centralized navigation
- Type-safe with constants
- Unified parameter handling
- Facilitates deep links

### Dependency Injection

Using Provider for global service dependency injection.

## Data flow

### Authentication

```
Login Screen
    ↓
Auth Service (API Call)
    ↓
Store Token (SharedPreferences)
    ↓
Update Auth State (Provider)
    ↓
Navigate to Dashboard
```

### Communication with backend

```
User Action
    ↓
Feature Service
    ↓
HTTP Service (core/network)
    ↓
API Backend
    ↓
Response Processing
    ↓
Update UI (Provider/setState)
```

## Error handling

### Error hierarchy

```
AppException (base)
├── NetworkException
│   ├── NoConnectionException
│   ├── TimeoutException
│   └── ServerException
├── AuthException
│   ├── InvalidCredentialsException
│   └── TokenExpiredException
└── ValidationException
```

### Gestion centralisée

- All errors inherit from `AppException`
- Uniform handling in `core/errors`
- Error messages localisés
- Centralized logging

## Performance

### Implemented optimizations

**Lazy Loading**
- Deferred loading of features
- Conditional import of heavy assets

**Caching**
- Local cache with SharedPreferences
- Network cache for images
- API response memorization

**Rendering**
- GlassPerformanceService to adapt graphics quality
- Use of const constructors
- Appropriate keys for lists

**Build Optimization**
- Split APK by ABI (Android)
- Tree-shaking to reduce size
- Obfuscation in production

## Security

### Implemented best practices

**Sensitive data**
- Tokens stored securely
- No sensitive data in plain text in code
- HTTPS communication only

**Validation**
- Client-side validation (email_validator)
- Input sanitization
- Permission verification

**Authentication**
- Session management with expiration
- Refresh tokens
- Automatic logout

## Tests

### Testing strategy

**Unit tests**
- Business services
- Data models
- Utilities

**Widget tests**
- Components réutilisables
- Critical screens

**Integration tests**
- Complete user flows
- Navigation
- API interaction

## Scalability

### Extensibility

**Adding a new feature:**

1. Create folder in `features/`
2. Implement models
3. Create screens and widgets
4. Add routes in `app_routes.dart`
5. Implement business logic
6. Add tests

**Modularity:**
- Each feature is independent
- Minimal dependencies between features
- Stable and decoupled core layer

## Multi-environment configuration

The application supports different environments:

- Development: Debug, detailed logs
- Staging: Pre-production tests
- Production: Optimized, obfuscated

Configuration via `app_config.dart` and environment variables.

## Best practices

### Code

- Follow Dart/Flutter conventions
- Use flutter_lints
- Public API documentation
- Explicit and consistent naming

### Architecture

- Separation of concerns
- DRY (Don't Repeat Yourself)
- SOLID principles
- Composition over inheritance

### Performance

- Avoid unnecessary rebuilds
- Use const when possible
- Profile regularly
- Lazy loading of resources

### Security

- Never secrets in code
- Input validation
- Permission handling
- Secure logging (no sensitive data)
