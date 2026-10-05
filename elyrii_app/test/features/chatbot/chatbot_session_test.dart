import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:elyrii_app/core/config/api_config.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/chatbot/data/repositories/chat_history_service.dart';
import 'package:elyrii_app/features/chatbot/data/entities/chat_message.dart';
import 'package:elyrii_app/features/chatbot/presentation/providers/chatbot_provider.dart';

class _Storage extends SecureStorageService {
  String owner = 'account-a';
  @override
  Future<String?> getUserId() async => owner;
  @override
  Future<String?> getAccessToken() async => 'fixture-only';
}

class _History extends ChatHistoryService {
  _History() : super(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
  Completer<void>? readGate;
  final readStarted = Completer<void>();
  @override
  Future<List<ChatMessage>> messages(
    String owner,
    String sessionId, {
    String? beforeId,
  }) async {
    final page = await super.messages(owner, sessionId, beforeId: beforeId);
    final gate = readGate;
    if (gate != null) {
      readGate = null;
      readStarted.complete();
      await gate.future;
    }
    return page;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test(
    'late reply stays in its originating session; switching accounts clears memory',
    () async {
      SharedPreferences.setMockInitialValues({});
      final previousUrl = ApiConfig.baseUrl;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      ApiConfig.setBaseUrl('http://127.0.0.1:${server.port}');
      final received = Completer<WebSocket>();
      WebSocket? peer;
      server.listen((request) async {
        peer = await WebSocketTransformer.upgrade(request);
        peer!.listen((data) {
          if (!received.isCompleted) received.complete(peer);
        });
      });
      final history = _History();
      final storage = _Storage();
      final provider = ChatbotProvider(storage: storage, history: history);
      addTearDown(() async {
        provider.dispose();
        await peer?.close();
        await server.close(force: true);
        await provider.flushed;
        await history.close();
        ApiConfig.setBaseUrl(previousUrl);
      });
      await provider.ready;
      await provider.sendMessage('Question dans A');
      final firstRequest = provider.messages.last.id;
      final original = provider.activeSessionId!;
      final socket = await received.future.timeout(const Duration(seconds: 3));
      await provider.startNewConversation();
      final delivered = Completer<void>();
      provider.addListener(() {
        if (provider.conversations.firstOrNull?.messageCount == 2 &&
            !delivered.isCompleted) {
          delivered.complete();
        }
      });
      socket.add(
        jsonEncode({
          'type': 'reply',
          'requestId': firstRequest,
          'conversationId': original,
          'message': 'Réponse dans A',
        }),
      );
      await delivered.future.timeout(const Duration(seconds: 3));
      expect(provider.messages, isEmpty);
      await provider.flushed;
      await provider.loadSession(original);
      expect(provider.messages.last.content, 'Réponse dans A');

      await provider.sendMessage('Deuxième question');
      final secondRequest = provider.messages.last.id;
      final readGate = Completer<void>();
      history.readGate = readGate;
      final selection = provider.loadSession(original);
      await history.readStarted.future;
      final newReply = Completer<void>();
      provider.addListener(() {
        if (provider.conversations.firstOrNull?.messageCount == 4 &&
            !newReply.isCompleted) {
          newReply.complete();
        }
      });
      socket.add(
        jsonEncode({
          'type': 'reply',
          'requestId': secondRequest,
          'conversationId': original,
          'message': 'Réponse reçue pendant la lecture SQLite',
        }),
      );
      await newReply.future.timeout(const Duration(seconds: 3));
      readGate.complete();
      await selection;
      expect(provider.messages, hasLength(4));
      expect(
        provider.messages.last.content,
        'Réponse reçue pendant la lecture SQLite',
      );

      storage.owner = 'account-b';
      await provider.synchronizeAccount();
      expect(provider.messages, isEmpty);
      expect(provider.conversations, isEmpty);
      storage.owner = 'account-a';
      await provider.synchronizeAccount();
      expect(provider.messages, hasLength(4));
    },
  );
}
