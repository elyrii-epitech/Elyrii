import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/features/chatbot/data/entities/chat_message.dart';
import 'package:elyrii_app/features/chatbot/data/entities/chat_session.dart';
import 'package:elyrii_app/features/chatbot/presentation/pages/chatbot_page.dart';
import 'package:elyrii_app/features/chatbot/presentation/providers/chatbot_provider.dart';
import 'package:elyrii_app/features/chatbot/presentation/widgets/chat_history_sheet.dart';
import '../../support/empty_chat_history.dart';

class _Storage extends SecureStorageService {
  @override
  Future<String?> getUserId() async => 'widget-test';
}

class _History extends EmptyChatHistory {
  final first = ChatSession.create().copyWith(
    title: 'Conversation A',
    messageCount: 1,
  );
  final second = ChatSession.create().copyWith(
    title: 'Conversation B',
    messageCount: 1,
  );
  Completer<void>? gate;
  bool fail = false;
  @override
  Future<List<ChatSession>> sessions(
    String owner, {
    ChatSession? before,
  }) async => [first, second];
  @override
  Future<List<ChatMessage>> messages(
    String owner,
    String sessionId, {
    String? beforeId,
  }) async {
    await gate?.future;
    if (fail) throw StateError('Read failed');
    return [
      ChatMessage.user(sessionId == first.id ? 'Message A' : 'Message B'),
    ];
  }
}

void main() {
  for (final fail in [false, true]) {
    testWidgets(
      'history stays open while loading and preserves the draft (${fail ? 'failure' : 'success'})',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final history = _History();
        final provider = ChatbotProvider(storage: _Storage(), history: history);
        addTearDown(provider.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: provider,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const ChatbotPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Brouillon conservé');
        await tester.tap(find.byTooltip('Actions de conversation'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Historique des conversations'));
        await tester.pumpAndSettle();
        history.gate = Completer<void>();
        history.fail = fail;
        await tester.tap(find.text('Conversation B'));
        await tester.pump();
        expect(find.byType(ChatHistorySheet), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(provider.activeSessionId, history.first.id);
        expect(provider.loadingSession, isTrue);
        history.gate!.complete();
        await tester.pumpAndSettle();
        expect(provider.loadingSession, isFalse);
        if (fail) {
          expect(find.byType(ChatHistorySheet), findsOneWidget);
          expect(
            find.text('Impossible de charger cette conversation.'),
            findsWidgets,
          );
          // Dismiss manually after the failure; the draft must still be there.
          Navigator.of(tester.element(find.byType(ChatHistorySheet))).pop();
          await tester.pumpAndSettle();
          expect(provider.activeSessionId, history.first.id);
        } else {
          expect(find.byType(ChatHistorySheet), findsNothing);
          expect(find.text('Message B'), findsOneWidget);
          expect(provider.activeSessionId, history.second.id);
        }
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Brouillon conservé',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
