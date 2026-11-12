import 'dart:convert';

import 'package:elyrii_app/app/app_dependencies.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/services/theme_provider.dart';
import 'package:elyrii_app/features/chatbot/data/entities/chat_message.dart';
import 'package:elyrii_app/features/chatbot/data/entities/chat_session.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Storage extends SecureStorageService {
  bool failRemoval = false;
  @override
  Future<void> clearAuthData() async {
    await super.clearAuthData();
    if (failRemoval) throw StateError('platform removal failed');
  }
}

void main() {
  test('account deletion purges all owned stores and preserves another account', () async {
    final token =
        'header.${base64Url.encode(utf8.encode(jsonEncode({'userId': 'alice', 'email': 'alice@example.test', 'exp': 2000000000})))}.signature';
    FlutterSecureStorage.setMockInitialValues({
      'access_token': token,
      'user_id': 'alice',
    });
    SharedPreferences.setMockInitialValues({
      'cache_dashboard_data_alice_30d': '{}',
      'cache_user_settings_alice': '{}',
      'cache_user_settings_bob': 'Bob settings',
      'account_settings_other_alice': 'Another account',
      'elyrii_mascot_legacy_owner': 'alice',
      'elyrii_mascot_theme': 'nature',
      'elyrii_seen_cosmetic_unlocks': ['glasses'],
    });
    final storage = _Storage();
    var deletes = 0;
    final api = ApiClient(
      storage: storage,
      client: MockClient((request) async {
        if (request.method == 'DELETE' && request.url.path == '/user/account') {
          deletes++;
          return http.Response('', 204);
        }
        if (request.url.path == '/user/me') {
          return http.Response(
            '{"id":"alice","email":"alice@example.test"}',
            200,
          );
        }
        if (request.url.path == '/user/settings') {
          return http.Response('{"id":"settings-alice","userId":"alice"}', 200);
        }
        if (request.url.path == '/user/mascot') {
          return http.Response('{"appearance":"nature"}', 200);
        }
        return http.Response('[]', 200);
      }),
    );
    final app = AppDependencies(
      storage: storage,
      api: api,
      theme: ThemeProvider(),
    );
    addTearDown(() async {
      app.dispose();
      await app.history.close();
      await app.journalStore.close();
    });
    await app.initialize();
    await app.user.loadSettings();
    await app.mascot.flushed;
    await app.journalStore.saveDraft('alice', 'new', {
      'content': 'Private Alice',
    });
    await app.journalStore.saveDraft('bob', 'new', {'content': 'Private Bob'});
    final alice = ChatSession.create();
    final bob = ChatSession.create();
    await app.history.append(
      'alice',
      alice,
      ChatMessage.user('Alice conversation'),
    );
    await app.history.append('bob', bob, ChatMessage.user('Bob conversation'));
    expect(await app.deleteAccount('fixture'), isTrue);
    expect(deletes, 1);
    expect(app.auth.isAuthenticated, isFalse);
    expect(await storage.getAccessToken(), isNull);
    expect(await storage.read(key: 'content_key_alice'), isNull);
    expect(await app.journalStore.readDraft('alice', 'new'), isNull);
    expect(
      (await app.journalStore.readDraft('bob', 'new'))!['content'],
      'Private Bob',
    );
    expect(await app.history.sessions('alice'), isEmpty);
    expect(await app.history.messages('bob', bob.id), hasLength(1));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('cache_user_settings_bob'), 'Bob settings');
    expect(prefs.getString('account_settings_other_alice'), 'Another account');
    expect(prefs.getString('elyrii_mascot_legacy_owner'), isNull);
    expect(prefs.getString('elyrii_mascot_theme'), isNull);
    expect(prefs.getStringList('pending_account_deletions'), isEmpty);
  });

  test('restart retries deletion and purges content even when credential removal fails', () async {
    FlutterSecureStorage.setMockInitialValues({
      'user_id': 'alice',
      'access_token': 'fixture',
    });
    SharedPreferences.setMockInitialValues({
      'pending_account_deletions': ['alice'],
    });
    final storage = _Storage()..failRemoval = true;
    final app = AppDependencies(
      storage: storage,
      api: ApiClient(
        storage: storage,
        client: MockClient((_) async => http.Response('[]', 200)),
      ),
      theme: ThemeProvider(),
    );
    addTearDown(() async {
      app.dispose();
      await app.history.close();
      await app.journalStore.close();
    });
    await app.journalStore.saveDraft('alice', 'new', {
      'content': 'Private content',
    });
    await expectLater(app.initialize(), throwsStateError);
    expect(await app.journalStore.readDraft('alice', 'new'), isNull);
    expect(await storage.read(key: 'content_key_alice'), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('pending_account_deletions'), ['alice']);
    storage.failRemoval = false;
    await app.initialize();
    expect(prefs.getStringList('pending_account_deletions'), isEmpty);
    expect(app.auth.isAuthenticated, isFalse);
  });
}
