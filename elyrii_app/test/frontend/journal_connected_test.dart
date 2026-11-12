import 'dart:io';

import 'package:elyrii_app/core/config/api_config.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:elyrii_app/features/journal/data/repositories/journal_repository.dart';
import 'package:elyrii_app/features/journal/presentation/providers/journal_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class _Connection extends http.BaseClient {
  final delegate = http.Client();
  bool offline = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (offline) throw const SocketException('Local offline fixture');
    return delegate.send(request);
  }

  @override
  void close() => delegate.close();
}

void main() {
  const enabled = bool.fromEnvironment('MOBILE_API_INTEGRATION');
  test('journal providers persist CRUD, deduplicate retries, retain offline drafts and isolate accounts', () async {
    const base = String.fromEnvironment(
      'MOBILE_TEST_API_URL',
      defaultValue: 'http://127.0.0.1:3188',
    );
    expect(Uri.parse(base).host, '127.0.0.1');
    final oldBase = ApiConfig.baseUrl;
    final overrides = HttpOverrides.current;
    HttpOverrides.global = null;
    ApiConfig.setBaseUrl(base);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    const password = 'JournalSecret123';
    final emails = List.generate(
      2,
      (_) => 'dart-journal-${const Uuid().v4()}@example.test',
    );
    final storage = SecureStorageService();
    final connection = _Connection();
    final api = ApiClient(storage: storage, client: connection);
    final auth = AuthProvider(client: api, storage: storage);
    api.onRefresh = auth.refreshAccessToken;
    final repository = JournalRepository(client: api);
    var journal = JournalProvider(repository: repository);
    void bind() => journal.onUserChanged(auth.accountId);
    addTearDown(() async {
      connection.offline = false;
      for (final email in emails) {
        try {
          await auth.login(email: email, password: password);
          await api.delete(
            ApiConfig.userAccountUrl,
            body: {'password': password},
          );
        } catch (_) {}
      }
      journal.dispose();
      await repository.store.close();
      await auth.clearLocalSession();
      auth.dispose();
      api.dispose();
      ApiConfig.setBaseUrl(oldBase);
      HttpOverrides.global = overrides;
    });
    expect(
      await auth.register(
        email: emails[0],
        password: password,
        firstName: 'Journal',
        lastName: 'Fixture',
      ),
      isTrue,
      reason: auth.error,
    );
    final owner = auth.accountId!;
    bind();
    final key = const Uuid().v4();
    final entry = await journal.createEntry(
      title: 'Mon journal',
      content: 'Première version',
      mood: 'happy',
      clientRequestId: key,
    );
    expect(entry, isNotNull, reason: journal.error);
    final replay = await journal.createEntry(
      title: 'Mon journal',
      content: 'Première version',
      mood: 'happy',
      clientRequestId: key,
    );
    expect(replay?.id, entry!.id);
    expect(journal.entries.length, 1);
    expect(
      await journal.updateEntry(
        entry.id,
        content: 'Texte modifié',
        mood: 'neutral',
      ),
      isTrue,
      reason: journal.error,
    );

    journal.dispose();
    journal = JournalProvider(repository: repository)..onUserChanged(owner);
    await journal.loadEntries();
    expect(journal.error, isNull);
    expect(journal.entries.single.content, 'Texte modifié');
    expect(journal.entries.single.mood, 'neutral');
    expect(journal.totalCount, 1);
    expect(journal.hasMore, isFalse);

    connection.offline = true;
    await journal.loadEntries();
    expect(journal.entries.single.id, entry.id);
    await journal.saveDraft('new', {
      'content': 'Brouillon privé',
      'clientRequestId': const Uuid().v4(),
    });
    expect(await journal.createEntry(content: 'Brouillon privé'), isNull);
    expect((await journal.readDraft('new'))?['content'], 'Brouillon privé');
    expect(journal.entries.length, 1);
    connection.offline = false;

    await auth.logout();
    expect(
      await auth.register(
        email: emails[1],
        password: password,
        firstName: 'Other',
        lastName: 'Fixture',
      ),
      isTrue,
      reason: auth.error,
    );
    bind();
    await journal.loadEntries();
    expect(journal.entries, isEmpty);
    expect(await journal.readDraft('new'), isNull);

    await auth.logout();
    expect(await auth.login(email: emails[0], password: password), isTrue);
    bind();
    await journal.loadEntries();
    expect(journal.entries.single.content, 'Texte modifié');
    expect((await journal.readDraft('new'))?['content'], 'Brouillon privé');
    expect(await journal.deleteEntry(entry.id), isTrue, reason: journal.error);
    await journal.loadEntries();
    expect(journal.entries, isEmpty);
    connection.offline = true;
    await journal.loadEntries();
    expect(
      journal.entries,
      isEmpty,
      reason: 'Confirmed deletions must not return offline',
    );
  }, skip: !enabled);
}
