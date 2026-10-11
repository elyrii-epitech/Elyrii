import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elyrii_app/core/config/api_config.dart';
import 'package:elyrii_app/core/config/dev_session.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/storage/content_cipher.dart';
import 'package:elyrii_app/features/journal/data/repositories/journal_repository.dart';
import 'package:elyrii_app/features/journal/data/repositories/journal_store.dart';
import 'package:elyrii_app/features/journal/data/models/journal_entry_model.dart';
import 'package:elyrii_app/features/journal/presentation/providers/journal_provider.dart';
import 'package:elyrii_app/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:elyrii_app/features/chatbot/presentation/widgets/crisis_detection_banner.dart';

class Storage extends SecureStorageService {
  String owner = 'alice';
  String token = 'fixture';
  @override
  Future<String?> getUserId() async => owner;
  @override
  Future<String?> getAccessToken() async => token;
}

JournalEntryModel note(String id) => JournalEntryModel(
  id: id,
  userId: 'alice',
  title: 'Note',
  content: 'Contenu privé',
  createdAt: DateTime.utc(2026, 10, 10),
  updatedAt: DateTime.utc(2026, 10, 10),
);

class DelayedJournal extends JournalRepository {
  DelayedJournal() : super(client: ApiClient(storage: Storage()));
  final load = Completer<List<JournalEntryModel>>();
  @override
  Future<List<JournalEntryModel>> getEntries({
    DateTime? startDate,
    DateTime? endDate,
  }) => load.future;
  @override
  Future<List<JournalEntryModel>> getCachedEntries({String? owner}) async => [];
  @override
  Future<JournalEntryModel> createEntry({
    required String title,
    String? content,
    String? mood,
    List<String>? tags,
    String? clientRequestId,
  }) async => note('new');
}

class FailingCopy extends JournalStore {
  FailingCopy(SecureStorageService storage)
    : super(cipher: ContentCipher(storage));
  @override
  Future<void> upsert(String owner, JournalEntryModel entry) async =>
      throw StateError('disk full');
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });
  test(
    'a GET started before creation cannot erase the acknowledged note',
    () async {
      final repository = DelayedJournal();
      final provider = JournalProvider(repository: repository);
      addTearDown(provider.dispose);
      final pending = provider.loadEntries();
      await Future<void>.delayed(Duration.zero);
      await provider.createEntry(content: 'Contenu privé');
      repository.load.complete([note('old')]);
      await pending;
      expect(provider.entries.map((e) => e.id), ['new']);
      expect(provider.isLoading, isFalse);
    },
  );
  test(
    'a local copy failure preserves server success and the request identity',
    () async {
      final storage = Storage();
      final store = FailingCopy(storage);
      addTearDown(store.close);
      var posts = 0;
      String? requestId;
      final api = ApiClient(
        storage: storage,
        client: MockClient((request) async {
          posts++;
          requestId =
              (jsonDecode(request.body) as Map)['clientRequestId'] as String;
          return http.Response(
            jsonEncode({'body': note('committed').toCacheJson()}),
            201,
          );
        }),
      );
      addTearDown(api.dispose);
      final repository = JournalRepository(client: api, store: store);
      final provider = JournalProvider(repository: repository);
      addTearDown(provider.dispose);
      expect(
        (await provider.createEntry(
          content: 'Contenu privé',
          clientRequestId: '856b2b62-fac4-4e58-8b7f-87bd735a4c43',
        ))!.id,
        'committed',
      );
      expect(posts, 1);
      expect(requestId, '856b2b62-fac4-4e58-8b7f-87bd735a4c43');
      expect(provider.error, isNull);
      expect(provider.storageWarning, contains('serveur'));
    },
  );
  test(
    'every demo HTTP operation stays local and real login still uses transport',
    () async {
      final storage = Storage()..owner = DevSession.userId;
      final payload = base64Url
          .encode(utf8.encode(jsonEncode({'sub': DevSession.userId})))
          .replaceAll('=', '');
      storage.token = 'e30.$payload.demo';
      var network = 0;
      final api = ApiClient(
        storage: storage,
        client: MockClient((_) async {
          network++;
          return http.Response('{"message":"real request"}', 200);
        }),
      );
      addTearDown(api.dispose);
      expect((await api.get(ApiConfig.userMeUrl))['id'], DevSession.userId);
      expect(
        (await api.get(ApiConfig.userSettingsUrl))['userId'],
        DevSession.userId,
      );
      await api.put(ApiConfig.userSettingsUrl, body: {'hapticsEnabled': false});
      final entry = await api.post(
        ApiConfig.journalUrl,
        body: {'title': 'Demo', 'content': 'Local'},
      );
      final id = entry['body']['id'] as String;
      await api.put(ApiConfig.journalEntryUrl(id), body: {'content': 'Edited'});
      await api.delete(ApiConfig.journalEntryUrl(id));
      expect(await api.get(ApiConfig.journalUrl), isEmpty);
      final session = await api.post(
        ApiConfig.startMeditationSessionUrl,
        body: {'type': 'coherence', 'durationMinutes': 5},
      );
      await api.post(
        ApiConfig.completeMeditationSessionUrl(session['id'] as String),
      );
      await api.get(ApiConfig.coachSessionsUrl);
      await api.post(ApiConfig.coachSessionsUrl, body: {'prompt': 'Demo'});
      await api.get('${ApiConfig.baseUrl}/user/export');
      expect(network, 0);
      await api.post(ApiConfig.loginUrl, auth: false);
      expect(network, 1);
    },
  );
  test('dashboard moods are encrypted, bound to the account, and legacy plaintext is discarded', () async {
    SharedPreferences.setMockInitialValues({
      'cache_dashboard_data_alice_7d': '{"latestMood":"sad"}',
    });
    final storage = Storage();
    final api = ApiClient(
      storage: storage,
      client: MockClient(
        (_) async =>
            http.Response('{"latestMood":"happy","stats":{"streak":3}}', 200),
      ),
    );
    addTearDown(api.dispose);
    final repository = DashboardRepository(client: api)
      ..onUserChanged(userId: 'alice');
    await repository.getDashboard();
    final prefs = await SharedPreferences.getInstance();
    final encrypted = prefs.getString('cache_dashboard_data_alice_30d')!;
    expect(encrypted, startsWith('aesgcm1:'));
    expect(encrypted, isNot(contains('happy')));
    expect(prefs.getString('cache_dashboard_data_alice_7d'), isNull);
    expect(
      await ContentCipher(storage)
          .open('alice', encrypted, purpose: 'dashboard:30d'),
      contains('happy'),
    );
    await expectLater(
      ContentCipher(storage).open('bob', encrypted, purpose: 'dashboard:30d'),
      throwsA(anything),
    );
  });
  test('distress cues cover French intent without matching ordinary verbs or unrelated substrings', () {
    for (final text in [
      'Je veux en finir',
      'Je ne veux plus vivre',
      'J’ai envie de mourir',
      'Je vais me tuer',
      'Je pense au suicide',
      'Je veux sauter du pont',
      'Je veux avaler tous mes médicaments',
      'Automutilation',
    ]) {
      expect(containsCrisisKeyword(text), isTrue, reason: text);
    }
    for (final text in [
      'Je vais sauter le petit déjeuner',
      'Je dois avaler mon médicament',
      'Je saute à la corde',
      'Mettre fin à cette discussion',
      'Je ne veux pas mourir',
      'Un projet suicidairement ambitieux',
    ]) {
      expect(containsCrisisKeyword(text), isFalse, reason: text);
    }
  });
}
