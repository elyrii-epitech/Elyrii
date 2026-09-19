# Chat reliability fixes — 20 September 2026

## Storage compatibility

Session metadata uses `INSERT OR IGNORE` followed by `UPDATE`, inside the
existing transaction. This works on older Android SQLite versions and preserves
message rows, counts and the original creation date. Do not substitute `REPLACE`:
deleting the parent session would cascade to its messages.

## Correlated WebSocket responses

New clients send `{message, requestId, conversationId}`. The request ID is the
UUID of the local user message; the conversation ID is the local session UUID.
The server returns `{type, message, requestId, conversationId}`, where `type` is
`reply` or `error`. Both identifiers must match a pending client request.
Duplicate, unknown, mismatched and already-completed responses are ignored.

The server generates a separate unique Kafka request ID and registers its
response listener **before** dispatching to Kafka. The originating WebSocket
controller sends exactly one terminal response. The consumer persists the AI
answer and resolves the matching listener; it no longer broadcasts through a
user's latest socket. A timeout removes the listener, so late AI results remain
in server history but do not overwrite another request's response.

Deploy the updated **chat backend before the mobile client**. The updated
backend keeps plain-text responses for legacy clients that omit `requestId`.
The updated mobile client intentionally does not guess the destination of
uncorrelated frames from an old backend: it displays an incompatibility error.
No Kafka topic, database migration, AI payload change or credential change is
required. This patch does not deploy any service.

## Conversation selection

History stays open with a progress indicator until selection succeeds. Failed
reads retain the previous conversation and show an error. Sending is blocked
in both the composer and provider while loading; the draft is not cleared when
submission is rejected. Successful selection preserves the draft too.

## Verification

- `flutter analyze --no-pub`: clean.
- `flutter test --no-pub`: 106 passing tests, including delayed/failed history
  selection with draft preservation, reordered replies, duplicate replies,
  timeout/late replies, and SQLite metadata preservation.
- `bun test`: 16 passing tests, including a real local WebSocket through the
  production controller/producer/consumer with database and Kafka fixtures.
- `bunx tsc --noEmit` and `bun run build`: successful.
- The production schema and metadata statements were executed successfully
  against SQLite **3.22.0**, compiled from the official SQLite amalgamation.
  This checks SQL compatibility, not a complete Android-device run.
- iOS simulator debug compilation succeeded. Browser-visible checks on iPhone
  17 Pro / iOS 26.4 verified sending/receiving in two separate conversations,
  switching history while retaining an unsent draft, and retrieving persisted
  messages after a Dart restart. The final Dart changes were hot-reloaded before
  those selection/restart checks. Responses came from a local fixture, not the
  production AI service. No physical Android device was used.

## Separate observation

The final simulator logs contained a mascot/WebView `MissingPluginException`
from `executeCustomJsCodeWithResult` targeting a missing `evaluateJavascript`
channel. `MascotModelController._command` in `mascot_model_surface.dart` starts
that future without awaiting or handling its failure. This is separate from
the three chat review findings and remains unresolved; the exact timing relative
to viewer release/app shutdown was not established. The chat checks above do
not constitute a claim that the entire app is runtime-error-free.
