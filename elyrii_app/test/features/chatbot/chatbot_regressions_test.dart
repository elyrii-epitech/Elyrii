import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:elyrii_app/core/config/api_config.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/chatbot/data/entities/chat_message.dart';
import 'package:elyrii_app/features/chatbot/data/entities/chat_session.dart';
import 'package:elyrii_app/features/chatbot/data/repositories/chat_history_service.dart';
import 'package:elyrii_app/features/chatbot/presentation/providers/chatbot_provider.dart';

class _Storage extends SecureStorageService {
  @override
  Future<String?> getUserId() async => 'test-owner';
  @override
  Future<String?> getAccessToken() async => 'test-only';
}

class _DelayedHistory extends ChatHistoryService {
  _DelayedHistory()
    : super(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
  Completer<void>? gate;
  Completer<void>? started;
  bool fail = false;
  @override
  Future<List<ChatMessage>> messages(
    String owner,
    String sessionId, {
    String? beforeId,
  }) async {
    if (gate != null) {
      started!.complete();
      await gate!.future;
    }
    if (fail) throw StateError('Read failed');
    return super.messages(owner, sessionId, beforeId: beforeId);
  }
}

Future<void> _until(ChatbotProvider provider, bool Function() condition) async {
  if (condition()) return;
  final done = Completer<void>();
  void listener() {
    if (condition() && !done.isCompleted) done.complete();
  }

  provider.addListener(listener);
  try {
    await done.future.timeout(const Duration(seconds: 3));
  } finally {
    provider.removeListener(listener);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'out-of-order, duplicate and late-after-timeout frames cannot cross conversations',
    () async {
      final oldUrl = ApiConfig.baseUrl;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      ApiConfig.setBaseUrl('http://127.0.0.1:${server.port}');
      final requests = StreamController<Map<String, dynamic>>();
      final iterator = StreamIterator(requests.stream);
      WebSocket? peer;
      server.listen((request) async {
        peer = await WebSocketTransformer.upgrade(request);
        peer!.listen(
          (data) =>
              requests.add(jsonDecode(data as String) as Map<String, dynamic>),
        );
      });
      final history = _DelayedHistory();
      final provider = ChatbotProvider(storage: _Storage(), history: history);
      addTearDown(() async {
        provider.dispose();
        await peer?.close();
        await server.close(force: true);
        await iterator.cancel();
        await requests.close();
        await provider.flushed;
        await history.close();
        ApiConfig.setBaseUrl(oldUrl);
      });
      void respond(
        Map<String, dynamic> request,
        String message, {
        String type = 'reply',
      }) {
        peer!.add(jsonEncode({...request, 'type': type, 'message': message}));
      }

      await provider.ready;
      await provider.sendMessage('Question A');
      await iterator.moveNext();
      final a = iterator.current;
      await provider.startNewConversation();
      await provider.sendMessage('Question B');
      await iterator.moveNext();
      final b = iterator.current;
      expect(a['conversationId'], isNot(b['conversationId']));
      expect(a['requestId'], isNot(b['requestId']));
      respond(b, 'Answer B');
      await _until(provider, () => provider.messages.length == 2);
      respond(a, 'Timeout A', type: 'error');
      await _until(
        provider,
        () => provider.conversations.every((s) => s.messageCount == 2),
      );
      expect(provider.messages.last.content, 'Answer B');

      await provider.sendMessage('Next question B');
      await iterator.moveNext();
      final nextB = iterator.current;
      respond(a, 'Late A');
      respond(b, 'Duplicate B');
      respond({
        ...nextB,
        'conversationId': a['conversationId'],
      }, 'Wrong conversation');
      respond(nextB, 'Next answer B');
      await _until(provider, () => !provider.isTyping);
      expect(provider.messages.map((m) => m.content), [
        'Question B',
        'Answer B',
        'Next question B',
        'Next answer B',
      ]);
      await provider.flushed;
      await provider.loadSession(a['conversationId'] as String);
      expect(provider.messages.map((m) => m.content), [
        'Question A',
        'Timeout A',
      ]);
      await provider.loadSession(b['conversationId'] as String);
      expect(provider.messages, hasLength(4));
    },
  );

  for (final fail in [false, true]) {
    test(
      'blocked selection rejects sends and releases the composer after ${fail ? 'failure' : 'success'}',
      () async {
        final history = _DelayedHistory();
        final first = ChatSession.create();
        final second = ChatSession.create();
        await history.append('test-owner', first, ChatMessage.user('First'));
        await history.append('test-owner', second, ChatMessage.user('Second'));
        final provider = ChatbotProvider(storage: _Storage(), history: history);
        addTearDown(() async {
          provider.dispose();
          await provider.flushed;
          await history.close();
        });
        await provider.ready;
        final previous = provider.activeSessionId;
        final target = previous == first.id ? second.id : first.id;
        history.gate = Completer<void>();
        history.started = Completer<void>();
        history.fail = fail;
        final selecting = provider.loadSession(target);
        await history.started!.future;
        expect(provider.loadingSession, isTrue);
        expect(
          await provider.sendMessage(
            'Must not reach the previous conversation',
          ),
          isFalse,
        );
        expect(provider.messages, hasLength(1));
        history.gate!.complete();
        expect(await selecting, !fail);
        expect(provider.loadingSession, isFalse);
        expect(provider.activeSessionId, fail ? previous : target);
        expect(provider.error, fail ? isNotNull : isNull);
        expect(
          (await history.sessions(
            'test-owner',
          )).every((s) => s.messageCount == 1),
          isTrue,
        );
      },
    );
  }
}
