# Elyrii client architecture

Code snapshot: October 6, 2026. The Flutter client is organized by feature,
with Provider for state/injection, GoRouter for navigation, and a shared HTTP
client connecting to the gateway.

## Organization

```text
elyrii_app/lib/
  app/
    app_dependencies.dart  # service composition and lifetime
    launch/                # short introduction and startup
    router/                # GoRouter, guards, persistent shell, transitions
  core/
    config/                # URLs and mascot configuration
    network/               # ApiClient, ApiException
    services/              # secure storage, theme, animation
    storage/               # platform SQLite and content encryption
    diagnostics/           # bounded events without private content
    theme/                 # visual design
    glass/ and widgets/    # shared components, surfaces, 3D rendering
  features/
    auth/ chatbot/ parcours/ dashboard/ gamification/
    journal/ mascot/ meditation/ settings/ …
```

Pages consume providers. Repositories handle REST exchanges and local storage;
`ApiClient` adds the Bearer token and enforces a timeout. Chat uses an
authenticated WebSocket to the gateway.

## Startup and navigation

1. `main.dart` installs error handlers and immediately displays the bootstrap UI.
2. Configuration, locales, and plugins initialize with recoverable errors,
   deadlines, and a retry button.
3. `AppDependencies` owns services and providers. It first resumes incomplete
   account purges, then restores the secure session without waiting for the network.
4. Each session change invalidates the HTTP client and all account state, then
   hydrates the profile, preferences, and gamification.
5. Pages load data through deduplicated requests. The router is recreated on
   account changes and disposed of with its owner.

Global providers cover theme, authentication, journal, chat, gamification,
profile/settings, mascot, dashboard, and journeys.

`AppRouter` uses `StatefulShellRoute.indexedStack` for six branches: Home,
Challenges, Journal, Meditation, Coach, and Chat. Guards handle authentication
and profile completion. Tab state persists; the mascot stops animating offscreen
and releases its viewer after 15 seconds.

## Network configuration

Resolution order: explicit argument, `ELYRII_API_URL`, legacy `BASE_URL`, then
a local address in development only. Other environments require an explicit
HTTPS URL. The default local port is **3001**, overridable with `ELYRII_API_PORT`.
The Android emulator uses `10.0.2.2`; iOS uses `localhost`. Supply the appropriate
URL explicitly:

```bash
flutter run --dart-define=ELYRII_API_URL=http://127.0.0.1:3001
```

All REST services go through the gateway. Chat opens `/chat/ws`. Service health
diagnostics run only in debug mode, on request:

```bash
flutter run --dart-define=CHECK_BACKEND_HEALTH=true
```

## Data and persistence

- **Authentication**: tokens and account ID in `SecureStorageService`. Logout
  clears the local session even if the remote call fails.
- **Chat**: `ChatHistoryService` uses SQLite with owner-indexed conversation and
  message tables. Writes are incremental and transactional; summary/message
  pages contain 50 items. Encryption migration is marked per account to avoid
  rereading the entire history at every startup. Provider getters no longer
  allocate a complete copy on every access. Each reply stays attached to its
  original conversation, even when the user switches conversations.
- **Chat migration**: the legacy global JSON does not identify its owner. The
  user must explicitly confirm recovery of the old history. The JSON remains
  available if import fails and is deleted only after the transaction succeeds.
- **Journal**: REST CRUD requests pages of 100 notes with filters, sorting, and
  stable cursors; entries and drafts use account-scoped encrypted SQLite. Legacy
  cache reads are filtered by `userId`. A 401/403 remains an error and cannot
  become a cached success. Logout also invalidates in-flight journal requests
  and clears memory state. Server pagination support remains a release dependency.
- **Journal editor**: only one save is in flight; a revision entered during the
  request still needs saving. A failed request does not produce a saved status.
- **Preferences**: theme and customization use SharedPreferences.
- **Journeys**: the editorial catalog lives in
  `features/parcours/data/journey_catalog.dart`. `JourneyProvider` retains one
  active, paused, or completed program. `JourneyRepository` stores a
  SharedPreferences document encrypted by `ContentCipher`, with its owner,
  version, and step snapshot. Progress is confirmed only after a successful
  local write; an error preserves the last confirmed state and requests a reload.
  Account changes invalidate late publications. Demo mode uses its own document.
  Purging waits for writes, then removes the owner's document. No server endpoint
  or schema is added. Progress is not synchronized across devices, and atomicity
  across browser tabs is not guaranteed. Built-in content version 1 can receive
  version 2 editorial text only when path ID, topic, ordered step IDs, durations,
  and action types/meditation targets match. Enrollment identity, progress,
  revision, and timestamps remain unchanged; unknown structures keep their
  stored snapshot. The next successful mutation persists the refreshed copy.

Chat titles/messages and journal entries/drafts are encrypted with AES-GCM
using an account key in secure storage, authenticated against the owner and
resource. Plaintext caches are migrated. Account deletion attempts every purge
and destroys its key; a marker retains failed steps for retry. Logout keeps
protected local data for a later login. Cross-device synchronization of local
chat history remains outside the contract.

### Chat contract

The native WebSocket uses the Bearer header and sends
`{message, requestId, conversationId}`. Each send/retry attempt gets a new
`requestId`, while the stored message ID stays stable. A response
`{type, message, requestId, conversationId}` is accepted only when both IDs
match a pending attempt. Duplicate and late responses are ignored; failures
and timeouts allow explicit retry. Switching conversations preserves the draft
and blocks sending while loading.

The compatible backend must ship before the client: an uncorrelated response
cannot identify its conversation. This dependency is tracked in
[#265](https://github.com/elyrii-epitech/Elyrii/issues/265). In SQLite, metadata
uses `INSERT OR IGNORE` followed by `UPDATE` within a transaction. Do not use
`REPLACE`: deleting the parent conversation would cascade-delete its messages.

## Rendering and performance

The dashboard uses focused selectors instead of subscribing the whole page to
four providers. Journal and history sheets build cards on demand with slivers.
Avatars are decoded at their physical display size.

The mascot and its headwear form a single 3D scene; original sources remain
in the repository. Optimized variants are reproducible through
`elyrii_app/tool/mascot/`.

Scene rebuilding is described in the [accessories guide](mascot-accessories.md).

## Limits of the guarantees

- No automatic refresh tokens; a 401 from the current session closes that
  session locally, without affecting an account signed in afterward.
- Widget tests and simulators do not measure physical-device FPS, power use,
  or GPU memory.
- Local fixtures do not certify real AI chat, Android hardware, or remote services.
- Only iOS and Android are release targets. Native builds, device plugins, and
  hardware profiling require their corresponding environments.

## Verification

```bash
cd elyrii_app
flutter analyze --no-pub
flutter test --no-pub
flutter build ios --simulator --debug --no-pub
```

CI uses Flutter 3.47.4. Its iOS artifact is explicitly a **simulator** application,
not a signed archive or TestFlight distribution.

Pre-distribution checks are listed in the [release guide](release.md) and
[accessibility protocol](accessibility.md).
