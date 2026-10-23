import 'dart:convert';
import 'dart:io';

import 'package:elyrii_app/core/config/api_config.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:elyrii_app/core/storage/content_cipher.dart';
import 'package:elyrii_app/features/chatbot/data/repositories/chat_history_service.dart';
import 'package:elyrii_app/features/chatbot/presentation/providers/chatbot_provider.dart';
import 'package:elyrii_app/features/coach/data/repositories/coach_repository.dart';
import 'package:elyrii_app/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:elyrii_app/features/gamification/data/repositories/gamification_repository.dart';
import 'package:elyrii_app/features/journal/data/repositories/journal_repository.dart';
import 'package:elyrii_app/features/mascot/data/models/mascot_model.dart';
import 'package:elyrii_app/features/mascot/data/repositories/mascot_repository.dart';
import 'package:elyrii_app/features/meditation/data/repositories/meditation_repository.dart';
import 'package:elyrii_app/features/settings/data/settings_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Opt-in: real mobile repositories/decoders through HTTP to a disposable API.
/// Never point this test at the production VPS: it creates and deletes fixtures.
void main() {
  const enabled = bool.fromEnvironment('MOBILE_API_INTEGRATION');
  test(
    'mobile repositories stay connected to the local backend and renew the session',
    () async {
      const base = String.fromEnvironment(
        'MOBILE_TEST_API_URL',
        defaultValue: 'http://127.0.0.1:3188',
      );
      final uri = Uri.parse(base);
      expect(uri.host, '127.0.0.1');
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      final oldBase = ApiConfig.baseUrl;
      final previousOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      ApiConfig.setBaseUrl(base);
      final storage = SecureStorageService();
      final api = ApiClient(storage: storage);
      final auth = AuthProvider(client: api, storage: storage);
      api.onRefresh = auth.refreshAccessToken;
      final users = UserRepository(client: api);
      final journal = JournalRepository(client: api);
      const password = 'Local mobile fixture password 2026!';
      addTearDown(() async {
        if (auth.isAuthenticated) await users.deleteAccount(password: password);
        await auth.clearLocalSession();
        auth.dispose();
        api.dispose();
        await journal.store.close();
        ApiConfig.setBaseUrl(oldBase);
        HttpOverrides.global = previousOverrides;
      });
      expect(
        await auth.register(
          email: 'dart-${const Uuid().v4()}@example.test',
          password: password,
          firstName: 'Mobile',
          lastName: 'Repository',
          age: 24,
        ),
        isTrue,
      );
      expect(await storage.getRefreshToken(), isNotEmpty);
      final results = await Future.wait([
        users.getMe(),
        users.getSettings(),
        DashboardRepository(client: api).getDashboard(),
      ]);
      expect(results, hasLength(3));
      expect(
        (await users.updateMe(firstName: 'Connecté', clearPfp: true)).firstName,
        'Connecté',
      );
      await users.updateSettings(themeMode: 'DARK', hapticsEnabled: false);
      expect((await users.getSettings()).themeMode, 'DARK');
      final mascot = MascotRepository(client: api);
      final look = MascotModel.defaultMascot().copyWith(
        equippedCosmetics: ['graduate_cap'],
      );
      await mascot.saveRemote(look);
      expect(
        (await mascot.getRemote(MascotModel.defaultMascot())).equippedCosmetics,
        ['graduate_cap'],
      );

      final note = await journal.createEntry(
        title: 'Connected mobile',
        content: 'A persisted repository fixture',
        clientRequestId: const Uuid().v4(),
      );
      expect(
        (await journal.getEntries()).any((entry) => entry.id == note.id),
        isTrue,
      );
      expect(
        (await journal.updateEntry(id: note.id, content: 'Edited')).content,
        'Edited',
      );
      final media = await journal.addMedia(
        entryId: note.id,
        url: 'https://example.test/image.png',
        type: 'image',
      );
      expect((await journal.listMedia(note.id)).single.id, media.id);
      await journal.deleteMedia(entryId: note.id, mediaId: media.id);

      final challenges = GamificationRepository(client: api);
      final available = await challenges.getAvailableChallenges();
      expect(available, isNotEmpty);
      final active = await challenges.startChallenge(available.first.id);
      expect(active.template?.title, available.first.title);
      final created = await api.post(
        '${ApiConfig.baseUrl}/challenge/proposals',
        body: {
          'title': 'Connected proposal',
          'conditions': [
            {'type': 'mood_count', 'target': 10},
          ],
          'constraints': <String, dynamic>{},
        },
      ) as Map;
      final accepted = await challenges.acceptChallenge(
        (created['userChallenge'] as Map)['id'] as String,
      );
      expect(accepted.displayTitle, 'Connected proposal');

      final meditation = MeditationRepository(client: api);
      expect(
        (await meditation.getCatalog()).any(
          (program) => program.id == 'coherence',
        ),
        isTrue,
      );
      final session = await meditation.startSession(
        type: 'coherence',
        durationMinutes: 5,
      );
      expect(
        (await meditation.completeSession(
          sessionId: session.id,
          moodAfter: 'calm',
        )).status,
        'COMPLETED',
      );
      final coach = CoachRepository(client: api);
      expect(
        (await coach.createSession(
          prompt: 'Une routine pour retrouver mon calme',
        )).response,
        isNotEmpty,
      );
      final dashboard = DashboardRepository(client: api);
      await dashboard.logMood('happy');
      expect((await dashboard.getDashboard()).latestMood, 'happy');

      // An expired access token forces real refresh; no re-login or mock transport.
      final oldRefresh = await storage.getRefreshToken();
      final payload = base64Url.encode(
        utf8.encode(
          jsonEncode({
            'userId': auth.accountId,
            'email': 'fixture@example.test',
            'exp': 1,
          }),
        ),
      );
      await storage.saveAccessToken('header.$payload.expired');
      expect((await users.getMe()).id, auth.accountId);
      expect(await storage.getRefreshToken(), isNot(oldRefresh));
      expect(auth.isAuthenticated, isTrue);
      if (const bool.fromEnvironment('MOBILE_CHAT_INTEGRATION')) {
        final history = ChatHistoryService(cipher: ContentCipher(storage));
        final chat = ChatbotProvider(
          storage: storage,
          history: history,
          accessToken: () async {
            final token = await storage.getAccessToken();
            return token != null && ApiClient.tokenNeedsRefresh(token)
                ? await auth.refreshAccessToken() ?? token
                : token;
          },
        );
        try {
          await chat.ready;
          await storage.saveAccessToken('header.$payload.expired');
          await chat.sendMessage('Conversation A ${const Uuid().v4()}');
          final first = chat.activeSessionId!;
          Future<void> waitForReply() async {
            final deadline = DateTime.now().add(const Duration(seconds: 15));
            while (chat.isTyping && DateTime.now().isBefore(deadline)) {
              await Future<void>.delayed(const Duration(milliseconds: 25));
            }
            expect(chat.error, isNull);
            expect(chat.messages.last.isUser, isFalse);
            expect(
              chat.messages.last.content,
              contains('Réponse de vérification locale'),
            );
          }

          await waitForReply();
          final remoteHistory = await api.get(
            '${ApiConfig.baseUrl}/chat/history',
            queryParams: {'conversationId': first},
          ) as List;
          expect(remoteHistory, hasLength(2));
          await chat.startNewConversation();
          await chat.sendMessage('Conversation B ${const Uuid().v4()}');
          await waitForReply();
          await chat.flushed;
          await chat.loadSession(first);
          expect(chat.messages, hasLength(2));
          expect(chat.messages.last.content, contains('Conversation A'));
        } finally {
          chat.dispose();
          await chat.flushed;
          await history.close();
        }
      }
      await journal.deleteEntry(note.id);
    },
    skip: !enabled,
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
