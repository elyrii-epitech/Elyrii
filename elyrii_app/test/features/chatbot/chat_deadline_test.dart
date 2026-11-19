import 'dart:async';
import 'dart:convert';

import 'package:elyrii_app/core/network/chat/chat_connection.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/chatbot/data/entities/chat_message.dart';
import 'package:elyrii_app/features/chatbot/data/repositories/chat_history_service.dart';
import 'package:elyrii_app/features/chatbot/presentation/providers/chatbot_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Connection implements ChatConnection {
  final input = StreamController<Object?>.broadcast(sync: true);
  final sent = <Map<String, dynamic>>[];
  @override
  Stream<Object?> get frames => input.stream;
  @override
  void send(String payload) =>
      sent.add(jsonDecode(payload) as Map<String, dynamic>);
  @override
  Future<void> close() async {
    if (!input.isClosed) await input.close();
  }

  void reply(Map<String, dynamic> request, String message) =>
      input.add(jsonEncode({...request, 'type': 'reply', 'message': message}));
}

void main() {
  test('missing reply expires, persists failure and retries without duplicating the user message', () async {
    final socket = _Connection();
    final history = ChatHistoryService(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final provider = ChatbotProvider(
      storage: SecureStorageService(),
      history: history,
      connector: (uri, {token}) async => socket,
      replyTimeout: const Duration(milliseconds: 60),
    );
    addTearDown(() async {
      provider.dispose();
      await socket.close();
      await provider.flushed;
      await history.close();
    });
    await provider.ready;
    expect(await provider.sendMessage('Question'), isTrue);
    final first = socket.sent.single;
    expect(provider.isTyping, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 90));
    expect(provider.isTyping, isFalse);
    expect(provider.messages.single.delivery, MessageDelivery.failed);
    await provider.flushed;
    expect(
      (await history.messages(
        'local-guest',
        provider.activeSessionId!,
      )).single.delivery,
      MessageDelivery.failed,
    );
    await provider.retryMessage(provider.messages.single.id);
    final second = socket.sent.last;
    expect(second['requestId'], isNot(first['requestId']));
    expect(provider.messages, hasLength(1));
    socket.reply(first, 'Late old reply');
    socket.reply(second, 'New reply');
    await Future<void>.delayed(Duration.zero);
    expect(provider.messages.map((m) => m.content), ['Question', 'New reply']);
    expect(provider.messages.first.delivery, MessageDelivery.delivered);
    expect(provider.isTyping, isFalse);
  });
  test(
    'account switch cancels deadlines and never sends an old-account draft',
    () async {
      final socket = _Connection();
      final gate = Completer<ChatConnection>();
      final history = ChatHistoryService(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final provider = ChatbotProvider(
        storage: SecureStorageService(),
        history: history,
        initialOwner: 'alice',
        connector: (uri, {token}) => gate.future,
        replyTimeout: const Duration(milliseconds: 60),
      );
      addTearDown(() async {
        provider.dispose();
        await socket.close();
        await provider.flushed;
        await history.close();
      });
      await provider.ready;
      final sending = provider.sendMessage('Alice private draft');
      await provider.flushed;
      await Future<void>.delayed(Duration.zero);
      await provider.onUserChanged('bob');
      gate.complete(socket);
      await sending;
      await Future<void>.delayed(const Duration(milliseconds: 90));
      expect(socket.sent, isEmpty);
      expect(provider.messages, isEmpty);
      expect(provider.isTyping, isFalse);
    },
  );
}
