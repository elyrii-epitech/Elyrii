import 'dart:convert';

import 'package:elyrii_app/app/app_dependencies.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:elyrii_app/features/chatbot/presentation/pages/chatbot_page.dart';
import 'package:elyrii_app/features/chatbot/presentation/widgets/chat_history_sheet.dart';
import 'package:elyrii_app/features/chatbot/data/entities/chat_message.dart';
import 'package:elyrii_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'support/native_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native chat sends, switches conversations, restores history and deletes through the new screens',
    (tester) async {
      const base = String.fromEnvironment('ELYRII_API_URL');
      expect(Uri.parse(base).host, '127.0.0.1');
      const password = 'ChatNative123';
      final client = http.Client();
      final storage = SecureStorageService();
      final registered = await client.post(
        Uri.parse('$base/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': 'ios-chat-${const Uuid().v4()}@example.test',
          'password': password,
          'firstName': 'Chat',
          'lastName': 'Fixture',
        }),
      );
      expect(registered.statusCode, 201, reason: registered.body);
      final session = jsonDecode(registered.body) as Map;
      final token = session['token'] as String;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
      ) as Map;
      final owner = payload['userId'] as String;
      await storage.saveAccessToken(token);
      await storage.saveRefreshToken(session['refreshToken'] as String);
      await storage.saveUserId(owner);
      await storage.setProfileSetupCompleted();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        final deleted = await client.delete(
          Uri.parse('$base/user/account'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'password': password}),
        );
        expect(deleted.statusCode, 200, reason: deleted.body);
        await storage.clearAuthData();
        await storage.clearProfileSetup(owner);
        client.close();
      });
      Future<AppDependencies> openChat() async {
        await waitFor(
          tester,
          () => find.byType(DashboardPage).evaluate().isNotEmpty,
          description: 'authenticated app',
        );
        tester.element(find.byType(DashboardPage)).go('/chatbot');
        await waitFor(
          tester,
          () => find.byType(ChatbotPage).evaluate().isNotEmpty,
          description: 'chat tab',
        );
        final services = tester
            .element(find.byType(ChatbotPage))
            .read<AppDependencies>();
        await services.chat.ready;
        return services;
      }

      Future<void> send(String text, AppDependencies services) async {
        // Let the native keyboard attach after returning from an action sheet
        // before injecting text into its editing connection.
        await tapVisible(tester, find.byType(TextField));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.enterText(find.byType(TextField), text);
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          text,
        );
        await tapVisible(tester, find.byTooltip('Envoyer le message'));
        await waitFor(
          tester,
          () => services.chat.messages.length == 2 && !services.chat.isTyping,
          description: 'persisted reply through Kafka',
        );
        expect(services.chat.error, isNull);
        expect(
          services.chat.messages.length,
          2,
          reason:
              'Connected: ${services.chat.isConnected}; delivery: ${services.chat.messages.map((m) => m.delivery.name).join(',')}',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 500));
      }

      app.main();
      var services = await openChat();
      const first = 'J’ai besoin d’une pause.';
      const second = 'Parlons de ma journée.';
      await send(first, services);
      final firstId = services.chat.activeSessionId!;
      await tapVisible(tester, find.byTooltip('Actions de conversation'));
      await tapVisible(tester, find.text('Nouvelle conversation'));
      await waitFor(
        tester,
        () =>
            services.chat.activeSessionId != firstId &&
            find.text('Nouvelle conversation').evaluate().isEmpty,
        description: 'new conversation and dismissed action sheet',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await send(second, services);
      final secondId = services.chat.activeSessionId!;
      expect(secondId, isNot(firstId));
      await tapVisible(tester, find.byTooltip('Historique des conversations'));
      await tapVisible(tester, find.text(first).last);
      await waitFor(
        tester,
        () =>
            services.chat.activeSessionId == firstId &&
            !services.chat.loadingSession &&
            find.byType(ChatHistorySheet).evaluate().isEmpty,
        description: 'first conversation selected',
      );
      expect(find.text(first), findsOneWidget);
      expect(find.text(second), findsNothing);
      await tester.runAsync(() async {
        await Future.wait([
          services.chat.flushed,
          services.user.flushed,
          services.mascot.flushed,
        ]);
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      app.main();
      services = await openChat();
      await tapVisible(tester, find.byTooltip('Historique des conversations'));
      await tapVisible(tester, find.text(first).last);
      await waitFor(
        tester,
        () =>
            services.chat.activeSessionId == firstId &&
            services.chat.messages.length == 2 &&
            !services.chat.loadingSession &&
            find.byType(ChatHistorySheet).evaluate().isEmpty,
        description: 'restored server conversation',
      );
      expect(find.text(first), findsOneWidget);
      expect(services.chat.messages.last.isUser, isFalse);
      expect(
        services.chat.messages.every(
          (message) => message.delivery == MessageDelivery.delivered,
        ),
        isTrue,
      );
      expect(find.text('Réponse non reçue'), findsNothing);
      debugPrint('CHAT_QA_FRAME_READY');
      if (const bool.fromEnvironment('HOLD_CHAT_QA_FRAME')) {
        await tester.pump(const Duration(milliseconds: 500));
        await Future<void>.delayed(const Duration(seconds: 20));
      }
      await tapVisible(tester, find.byTooltip('Historique des conversations'));
      final delete = find.byTooltip('Supprimer la conversation');
      // History is newest-first; the first conversation is the older second row.
      await tapVisible(tester, delete.last);
      await tapVisible(tester, find.text('Supprimer').last);
      await waitFor(
        tester,
        () => services.chat.conversations.length == 1,
        description: 'confirmed remote deletion',
      );
      expect(services.chat.conversations.single.id, secondId);
      final remote = await client.get(
        Uri.parse('$base/chat/history?conversationId=$firstId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      expect(jsonDecode(remote.body), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
