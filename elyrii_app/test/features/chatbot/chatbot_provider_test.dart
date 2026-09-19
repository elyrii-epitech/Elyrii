import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/chatbot/presentation/providers/chatbot_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:elyrii_app/features/chatbot/data/repositories/chat_history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('first message can be stored when history starts empty', () async {
    final history = ChatHistoryService(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final provider = ChatbotProvider(
      storage: SecureStorageService(),
      history: history,
    );
    await provider.ready;

    await provider.sendMessage('Bonjour Elyrii');

    expect(provider.messages, hasLength(2));
    expect(provider.messages.first.content, 'Bonjour Elyrii');
    expect(provider.messages.first.isUser, isTrue);
    expect(provider.messages.last.isUser, isFalse);
    expect(provider.conversations, hasLength(1));
    expect(provider.conversations.first.messageCount, 2);
    expect(identical(provider.messages, provider.messages), isTrue);
    await provider.flushed;
    expect(
      await history.messages('local-guest', provider.activeSessionId!),
      hasLength(2),
    );

    provider.dispose();
    await history.close();
  });
}
