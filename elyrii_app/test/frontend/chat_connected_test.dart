import 'dart:convert';
import 'dart:io';

import 'package:elyrii_app/core/config/api_config.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:elyrii_app/features/chatbot/data/entities/chat_message.dart';
import 'package:elyrii_app/features/chatbot/data/repositories/connected_chat_history.dart';
import 'package:elyrii_app/features/chatbot/presentation/providers/chatbot_provider.dart';
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

Future<void> until(bool Function() condition) async {
  final watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > const Duration(seconds: 10)) {
      fail('Timed out waiting for local chat');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  test('connected chat restores server history, refreshes auth, retries offline sends and isolates owners', () async {
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
    final storage = SecureStorageService();
    final connection = _Connection();
    final api = ApiClient(storage: storage, client: connection);
    final auth = AuthProvider(client: api, storage: storage);
    api.onRefresh = auth.refreshAccessToken;
    var history = ConnectedChatHistory(client: api);
    ChatbotProvider makeChat() => ChatbotProvider(
      storage: storage,
      history: history,
      authorizeConnection: () async {
        await api.get(ApiConfig.userMeUrl);
      },
    );
    var chat = makeChat();
    final emails = List.generate(
      2,
      (_) => 'dart-chat-${const Uuid().v4()}@example.test',
    );
    const password = 'ChatSecret123';
    addTearDown(() async {
      connection.offline = false;
      chat.dispose();
      await chat.flushed;
      await history.close();
      for (final email in emails) {
        try {
          await auth.login(email: email, password: password);
          await api.delete(
            ApiConfig.userAccountUrl,
            body: {'password': password},
          );
        } catch (_) {}
      }
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
        firstName: 'Chat',
        lastName: 'Fixture',
      ),
      isTrue,
      reason: auth.error,
    );
    final owner = auth.accountId!;
    await chat.onUserChanged(owner);
    expect(await chat.sendMessage('J’ai besoin de parler.'), isTrue);
    await until(() => !chat.isTyping);
    expect(chat.error, isNull);
    expect(chat.messages.length, 2);
    expect(chat.messages.first.delivery, MessageDelivery.delivered);
    final conversation = chat.activeSessionId!;
    final firstReplyId = chat.messages.last.id;

    // HTTP preflight shares the real native refresh implementation.
    await chat.disconnect();
    final oldRefresh = await storage.getRefreshToken();
    final token = (await storage.getAccessToken())!;
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
    ) as Map;
    payload['exp'] = 1;
    await storage.saveAccessToken(
      'header.${base64Url.encode(utf8.encode(jsonEncode(payload)))}.expired',
    );
    expect(await chat.sendMessage('Une deuxième question.'), isTrue);
    await until(() => !chat.isTyping);
    expect(chat.error, isNull);
    expect(await storage.getRefreshToken(), isNot(oldRefresh));
    expect(chat.messages.length, 4);
    await chat.flushed;

    // A brand-new SQLite store proves retrieval from the backend, not a cache.
    chat.dispose();
    await chat.flushed;
    await history.close();
    history = ConnectedChatHistory(client: api);
    chat = makeChat();
    await chat.ready;
    expect(chat.activeSessionId, conversation);
    expect(chat.messages.length, 4);
    expect(chat.messages[1].id, firstReplyId);
    expect(
      chat.messages.every(
        (message) => message.delivery == MessageDelivery.delivered,
      ),
      isTrue,
    );

    await chat.disconnect();
    connection.offline = true;
    expect(await chat.sendMessage('À réessayer hors connexion.'), isTrue);
    await until(() => !chat.isTyping);
    final failed = chat.messages.last;
    expect(failed.delivery, MessageDelivery.failed);
    connection.offline = false;
    await chat.retryMessage(failed.id);
    await until(() => !chat.isTyping);
    expect(chat.error, isNull);
    expect(chat.messages.where((m) => m.id == failed.id), hasLength(1));
    expect(chat.messages.length, 6);

    await auth.logout();
    expect(
      await auth.register(
        email: emails[1],
        password: password,
        firstName: 'Other',
        lastName: 'Fixture',
      ),
      isTrue,
    );
    await chat.onUserChanged(auth.accountId);
    expect(chat.messages, isEmpty);
    expect(chat.conversations, isEmpty);
    await auth.logout();
    expect(await auth.login(email: emails[0], password: password), isTrue);
    await chat.onUserChanged(owner);
    expect(chat.messages.length, 6);
    await chat.deleteSession(conversation);
    expect(chat.conversations, isEmpty);
    await chat.refreshHistory();
    expect(chat.conversations, isEmpty);
    connection.offline = true;
    await chat.refreshHistory();
    expect(chat.conversations, isEmpty);
  }, skip: !const bool.fromEnvironment('MOBILE_API_INTEGRATION'));
}
