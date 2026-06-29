# Elyrii Mobile Features

This page describes the features currently present in `elyrii_app/lib/features`.
It separates backend-backed behavior, local behavior, and code that is still
preparatory.

## Authentication

**Location:** `lib/features/auth/`

### Screens

- `LoginPage`
- `RegisterPage`

### Features

- Email/password login through `POST /auth/login`.
- Account creation through `POST /auth/register`.
- Client-side validation:
  - email through `email_validator`;
  - login password: at least 6 characters;
  - registration password: at least 8 characters, one uppercase letter, and one
    digit;
  - password confirmation;
  - terms acceptance.
- JWT decoding to extract `userId` and `email`.
- `access_token` and `user_id` storage through `SecureStorageService`.
- Current profile fetch through `GET /user/me`.
- Logout through `POST /auth/logout`, then local auth data cleanup.
- Backend `emailVerificationRequired` handling.
- Debug-only "Passer (Dev)" button visible in `kDebugMode`.

### Notes

The "Continue with Google" and "Continue with Apple" buttons are present in the
UI, but they are not wired to an OAuth provider yet.

## Dashboard

**Location:** `lib/features/dashboard/`

### Screen

- `DashboardPage`

### Features

- Greeting based on current time.
- Daily mood selection:
  - `verySad`
  - `sad`
  - `neutral`
  - `happy`
  - `veryHappy`
- Mood logging through `POST /user/mood`.
- Latest mood fetch through `GET /user/mood/latest`.
- User stats fetch through `GET /user/stats`:
  - streak;
  - active challenge count;
  - journal entry count.
- Local quote of the day.
- Local daily goal:
  - journal;
  - meditation;
  - breathing;
  - gratitude.
- Mood-aware mascot messages.
- Visual shortcuts to primary actions.
- Settings button from the dashboard.

## Journal

**Location:** `lib/features/journal/`

### Screen

- `JournalPage`

### Features

- Entry loading through `GET /journal`.
- Creation through `POST /journal`.
- Update through `PUT /journal/:id`.
- Soft delete through `DELETE /journal/:id`.
- Model fields:
  - `id`
  - `userId`
  - `title`
  - `content`
  - `mood`
  - `createdAt`
  - `updatedAt`
- Local newest/oldest sorting.
- Liquid Glass bottom sheet for creating or editing an entry.
- Empty state with writing prompts.
- Animated list, with animation limited to the first items to reduce jank.

### Notes

The repository supports `startDate` and `endDate` filters, but the current UI
does not expose them yet.

## Chatbot

**Location:** `lib/features/chatbot/`

### Screen

- `ChatbotPage`

### Features

- WebSocket connection to `ApiConfig.chatWsUrl(userId)`.
- URL built from the gateway base URL:
  `ws://.../chat/ws?userId=<userId>`.
- User messages sent over WebSocket.
- AI responses received and appended to local in-memory history.
- Typing indicator while waiting for a response.
- Reverse auto-scroll in the message list.
- Conversation suggestions when history is empty.
- Manual local history clearing.
- 3D mascot in full-screen mode before focus, then minimized mode when the text
  field is focused.
- "Urgence" button with emergency resources.
- Local French crisis keyword detection:
  - suicide;
  - suicidaire;
  - mourir;
  - finir ma vie;
  - ne plus en pouvoir;
  - automutilation;
  - me faire du mal;
  - mettre fin;
  - sauter;
  - avaler.
- Help banners and dialogs showing:
  - Fil Sante Jeunes: `0 800 235 236`;
  - SOS Amitie: `09 72 39 40 50`;
  - suicide prevention: `3114`;
  - life-threatening emergency: `15` or `112`.

### Notes

Chat history is not persisted on mobile. `mock_responses.dart` still exists, but
the provider now uses the real WebSocket.

## Gamification / Jardin

**Location:** `lib/features/gamification/`

### Screen

- `ChallengesPage`

### Backend Features

- Parallel loading of:
  - available challenges: `GET /challenge/available`;
  - active challenges: `GET /challenge/active`;
  - completed challenges: `GET /challenge/completed`;
  - AI proposals: `GET /challenge/proposals`.
- Start a system challenge through `POST /challenge/available/:id/start`.
- Accept an AI proposal through `POST /challenge/proposals/:id/accept`.
- Reject an AI proposal through `POST /challenge/proposals/:id/reject`.
- Progress computed from the backend `progress` field.
- Status support for `ACTIVE`, `COMPLETED`, and `PENDING`.

### UI Features

- "Atelier de presence" / "Ton jardin interieur" header.
- Local level derived from completed challenge count.
- Local XP derived from completed challenge count.
- Streak read from `DashboardProvider`.
- Local badges:
  - Premier pas;
  - Explorateur;
  - Pleine conscience;
  - Ecoute active;
  - Etoile du soir;
  - Lumiere du matin.
- Pull-to-refresh.
- Liquid Glass dialog when tapping a badge.

### Notes

There is no leaderboard or reward shop in the current mobile code.

## Coach

**Location:** `lib/features/coach/`

### Screen

- `CoachPage`

### Features

- Advice of the day computed locally from the day of year.
- Local recommended activities.
- Local activity catalog by category:
  - meditation;
  - breathing;
  - journaling;
  - gratitude;
  - movement;
  - self-compassion.
- Animated Liquid Glass cards.
- Haptic feedback on cards.

### Notes

The coach does not call the backend yet. `CoachRepository` is a local data
source.

## Meditation / Breathing

**Location:** `lib/features/meditation/`

### Screen

- `MeditationPage`

### Features

- Page focused on breathing exercises.
- Available durations:
  - 5 minutes;
  - 10 minutes;
  - 15 minutes.
- Available exercises:
  - 4-7-8 breathing: inhale 4s, hold 7s, exhale 8s;
  - box breathing: inhale 4s, hold 4s, exhale 4s, hold 4s.
- Per-second timer.
- Session states:
  - setup;
  - running;
  - paused;
  - finished.
- Animated breathing circle.
- Pause, resume, and stop.
- Post-session mood choice.
- Lottie animation `assets/animations/breath.json`.

### Notes

`data/models/meditation_session_model.dart` and
`data/repositories/meditation_repository.dart` are still placeholders. Sessions
are not persisted yet.

## 3D Mascot

**Location:** `lib/features/mascot/` and `lib/core/widgets/mascot_3d_viewer.dart`

### Screen

- `MascotCustomizationPage`

### Features

- 3D viewer based on `flutter_3d_controller`.
- PNG fallback `assets/mascotte.png` on error or widget tests.
- Embedded `idle` animation in the GLB.
- Context-specific configuration:
  - auth page;
  - full chatbot;
  - minimized chatbot.
- Theme customization with `ColorFilter.matrix`.
- Available themes:
  - Nature;
  - Halloween;
  - Panda;
  - Noel;
  - Cosmic;
  - Ocean.
- Theme persistence in `SharedPreferences`.
- Current accessory:
  - `custom1.glb`, displayed as a graduation hat.
- Reset to `nature` theme and no accessory.

### Main Assets

- `assets/base_basic_shaded_v3.glb`
- `assets/custom1.glb`
- `assets/mascotte.png`
- `assets/mascotte_eyes_closed.png`
- `assets/animations/breath.json`
- `assets/animations/Coucou.json`

## Settings

**Location:** `lib/features/settings/`

### Screen

- `SettingsPage`

### UI Features

- Appearance section:
  - dark mode switch;
  - persistence through `ThemeProvider`.
- Notifications section:
  - push notifications switch local to the page;
  - haptic feedback switch local to the page.
- Account section:
  - information dialogs for profile, privacy, data, and storage.
- About section:
  - version `1.0.0 (Build 1)`;
  - terms of use;
  - privacy policy.
- Logout with confirmation dialog.
- Route to login with `pushNamedAndRemoveUntil`.

### Data Features

- `UserProvider` and `UserRepository` can load and update `/user/me`.
- The profile editing form is not exposed in the UI yet.

## Global Navigation

The main navigation contains:
- Home;
- Jardin;
- Journal;
- Meditation;
- Coach;
- Chatbot through a separate bubble button.

Declarative routes:

```dart
class AppRoutes {
  static const String home = '/';
  static const String dashboard = '/dashboard';
  static const String challenges = '/challenges';
  static const String journal = '/journal';
  static const String coach = '/coach';
  static const String meditation = '/meditation';
  static const String chatbot = '/chatbot';
  static const String mascotCustomization = '/mascot-customization';
  static const String settings = '/settings';
  static const String login = '/login';
  static const String register = '/register';
}
```

## Cross-Cutting Systems

### Error Boundary

`GlobalErrorBoundary` replaces Flutter's error screen with a cleaner recovery
screen and adds a button to return home. Technical details are intended for
debugging.

### Liquid Glass

Liquid Glass components cover:
- cards;
- buttons;
- icon buttons;
- list tiles;
- switches;
- sliders;
- segmented controls;
- dialogs;
- sheets;
- action sheets;
- text fields;
- toasts;
- app bars.

### Glass Performance

`GlassPerformanceService` exposes:
- `reduceEffects`;
- `adaptiveBlurOnScroll`;
- `showSpecularHighlight`;
- `showTransitionAnimations`;
- `showAdaptiveGradient`;
- `getEffectiveBlurSigma`;
- `getScrollAdaptedBlurSigma`.

### Responsive

`Responsive` defines these breakpoints:
- compact: `< 360`;
- phone: `< 600`;
- foldable: `< 840`;
- tablet: `< 1200`;
- desktop: `>= 1200`.
