import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/chatbot/presentation/providers/chatbot_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('first message can be stored when history starts empty', () async {
    final provider = ChatbotProvider(storage: SecureStorageService());
    await Future<void>.delayed(const Duration(milliseconds: 10));

    await provider.sendMessage('Bonjour Elyrii');

    expect(provider.messages, hasLength(2));
    expect(provider.messages.first.content, 'Bonjour Elyrii');
    expect(provider.messages.first.isUser, isTrue);
    expect(provider.messages.last.isUser, isFalse);
    expect(provider.conversations, hasLength(1));
    expect(provider.conversations.first.messages, hasLength(2));

    provider.dispose();
  });
}
