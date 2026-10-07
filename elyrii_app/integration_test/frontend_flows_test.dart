import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart' show FocusManager, IconButton, TextField;
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:elyrii_app/app/app_dependencies.dart';
import 'package:elyrii_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:elyrii_app/features/chatbot/presentation/pages/chatbot_page.dart';
import 'package:elyrii_app/features/meditation/presentation/pages/meditation_page.dart';
import 'package:elyrii_app/core/widgets/glass_navigation_bar.dart';
import 'package:elyrii_app/core/widgets/glass_bubble_button.dart';
import 'package:elyrii_app/core/storage/local_database.dart';
import 'package:elyrii_app/core/storage/content_cipher.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/chatbot/data/entities/chat_message.dart';
import 'package:elyrii_app/features/chatbot/data/entities/chat_session.dart';
import 'package:elyrii_app/features/chatbot/data/repositories/chat_history_service.dart';

import 'support/native_app.dart';

/// Runs with real secure storage, SQLite and mascot platform views on a device.
/// The demo fixture does not require production credentials or an AI backend.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real bootstrap, restored demo and primary navigation', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    await startDemoApp(tester);
    expect(find.byType(DashboardPage), findsOneWidget);
    expect(find.byType(GlassNavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tapVisible(tester, find.byType(GlassBubbleButtonStateful));
    await waitFor(
      tester,
      () => find.byType(ChatbotPage).evaluate().isNotEmpty,
      description: 'the chat page',
    );
    expect(find.byType(ChatbotPage), findsOneWidget);
    final services = tester
        .element(find.byType(ChatbotPage))
        .read<AppDependencies>();
    await tester.runAsync(() => services.chat.ready);
    const message = 'Native integration persistence fixture';
    await tester.enterText(find.byType(TextField).last, message);
    await tapVisible(
      tester,
      find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            widget.tooltip == 'Envoyer le message' &&
            widget.onPressed != null,
        description: 'the enabled send-message button',
      ),
    );
    await waitFor(
      tester,
      () => services.chat.messages.any(
        (item) => item.isUser && item.content == message,
      ),
      description: 'the submitted user message to enter the conversation',
    );
    await tester.runAsync(() => services.chat.flushed);
    final messages = await tester.runAsync(
      () => services.history.messages(
        services.auth.accountId!,
        services.chat.activeSessionId!,
      ),
    );
    expect(
      messages!.any((item) => item.isUser && item.content == message),
      isTrue,
      reason: 'The submitted user message must be saved to native history.',
    );
    await tester.runAsync(() => services.chat.disconnect());
    FocusManager.instance.primaryFocus?.unfocus();
    await tapVisible(
      tester,
      find.bySemanticsLabel(RegExp(r'^Onglet Méditation,')),
    );
    await waitFor(
      tester,
      () => find.byType(MeditationPage).evaluate().isNotEmpty,
      description: 'the meditation page',
    );
    expect(find.byType(MeditationPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('native encrypted history survives reopening and account purge', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final factory = LocalDatabase.factory;
      final path = await LocalDatabase.path('elyrii_ci_chat.db', factory);
      const owner = 'native-ci-history';
      final cipher = ContentCipher(SecureStorageService());
      var history = ChatHistoryService(
        factory: factory,
        path: path,
        cipher: cipher,
      );
      try {
        final session = ChatSession.create();
        final message = ChatMessage.user('Native SQLite round trip');
        await history.append(owner, session, message);
        await history.close();
        history = ChatHistoryService(
          factory: factory,
          path: path,
          cipher: cipher,
        );
        expect(
          (await history.messages(owner, session.id)).single.content,
          message.content,
        );
        await history.deleteOwner(owner);
        await history.close();
        history = ChatHistoryService(
          factory: factory,
          path: path,
          cipher: cipher,
        );
        expect(await history.sessions(owner), isEmpty);
        expect(await history.messages(owner, session.id), isEmpty);
      } finally {
        await history.close();
        await factory.deleteDatabase(path);
        await cipher.deleteOwner(owner);
      }
    });
  });
}
