# Demo conversation

Enable the local scripted chat when running the app:

```sh
flutter run --dart-define=ELYRII_DEMO_CHAT=true
```

For an installable Android demo build:

```sh
flutter build apk --release --dart-define=ELYRII_DEMO_CHAT=true
```

Run these commands from `elyrii_app`. Keep your usual device and API URL flags.
The flag is compiled into the app: rebuild/relaunch to change it; hot reload
will not switch modes. Omit the flag (or set it to `false`) for real AI chat.

Only chat replies are simulated. Login and other features still use their
normal services. Demo chat never opens the chat WebSocket or calls the AI,
and its messages stay in memory rather than being saved to the server.
Present this as a scripted prototype/demo, not live model output.

## Rehearsal script

1. **Salut !** — a friendly greeting.
2. **Je suis un peu stressé pour ma présentation demain.** — acknowledges
   the pressure and offers a breathing exercise.
3. **Oui, je veux bien.** — accepts the previous offer and starts the exercise.
4. **Je me sens mieux, plus calme.** — acknowledges the improvement.
5. **Merci pour ton aide !** — closes warmly.

You can also try **J’ai du mal à dormir**, **Je me sens seul(e)**, or
**J’ai besoin d’en parler**. The existing suggestion chips work too.
Matching uses French keywords, tolerates accents, punctuation and capitalization,
and allows extra words; it is not semantic AI or unrestricted typo correction.
Unrecognized prompts receive a neutral prepared follow-up, with no network fallback.

Each topic has three replies selected randomly without consecutive repeats for
that topic. The existing animated typing dots appear immediately, followed by a
reply after 1.1–2.8 seconds, depending on length and random timing variation.
Rapid messages are answered in order. Clearing the conversation cancels pending
replies and resets the script context.

Edit topics, patterns and reply pools in
`lib/features/chatbot/data/demo_conversation.dart`.

Validate with:

```sh
flutter test test/features/chatbot/demo_conversation_test.dart
```
