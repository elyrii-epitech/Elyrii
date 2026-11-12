import 'dart:convert';

import 'package:elyrii_app/app/app_dependencies.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:elyrii_app/features/journal/presentation/pages/journal_page.dart';
import 'package:elyrii_app/features/journal/presentation/pages/journal_entry_page.dart';
import 'package:elyrii_app/features/journal/presentation/widgets/journal_editor_sheet.dart';
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
    'native journal writes, edits, restores and deletes real server notes',
    (tester) async {
      const base = String.fromEnvironment('ELYRII_API_URL');
      expect(Uri.parse(base).host, '127.0.0.1');
      const password = 'JournalNative123';
      final client = http.Client();
      final storage = SecureStorageService();
      final registered = await client.post(
        Uri.parse('$base/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': 'ios-journal-${const Uuid().v4()}@example.test',
          'password': password,
          'firstName': 'Journal',
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

      Future<void> openJournal() async {
        await waitFor(
          tester,
          () => find.byType(DashboardPage).evaluate().isNotEmpty,
          description: 'restored authenticated app',
        );
        tester.element(find.byType(DashboardPage)).go('/journal');
        await waitFor(
          tester,
          () => find.byType(JournalPage).evaluate().isNotEmpty,
          description: 'journal tab',
        );
        await tester.pump(const Duration(milliseconds: 500));
      }

      Future<List<dynamic>> serverNotes() async {
        final response = await client.get(
          Uri.parse('$base/journal?limit=100'),
          headers: {'Authorization': 'Bearer $token'},
        );
        expect(response.statusCode, 200, reason: response.body);
        return (jsonDecode(response.body) as Map)['entries'] as List;
      }

      app.main();
      await openJournal();
      var services = tester
          .element(find.byType(JournalPage))
          .read<AppDependencies>();
      await tapVisible(tester, find.text('Écrire'));
      await waitFor(
        tester,
        () => find.byType(JournalEditorSheet).evaluate().isNotEmpty,
        description: 'inline composer',
      );
      await tester.enterText(
        find.byType(TextField).at(0),
        'Une pause pour moi',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'Aujourd’hui, j’ai pris le temps de respirer.',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tapVisible(tester, find.text('Humeur'));
      await tapVisible(tester, find.bySemanticsLabel('Bof'));
      await tapVisible(tester, find.text('Enregistrer'));
      await waitFor(
        tester,
        () =>
            find.byType(JournalEditorSheet).evaluate().isEmpty &&
            services.journal.entries.isNotEmpty,
        description: 'acknowledged journal save',
      );
      final id = services.journal.entries.single.id;
      final first = (await serverNotes()).single as Map;
      expect(first, containsPair('mood', 'neutral'));
      expect(first['content'], 'Aujourd’hui, j’ai pris le temps de respirer.');

      await tapVisible(tester, find.text('Une pause pour moi').last);
      await waitFor(
        tester,
        () => find.byType(JournalEntryPage).evaluate().isNotEmpty,
        description: 'saved note reader',
      );
      await tapVisible(tester, find.byTooltip('Actions de la note'));
      await tapVisible(tester, find.text('Modifier'));
      await waitFor(
        tester,
        () => find.byType(JournalEditorSheet).evaluate().isNotEmpty,
        description: 'edit sheet',
      );
      await tester.enterText(
        find.byType(TextField).last,
        'Une petite pause m’a fait du bien.',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tapVisible(tester, find.text('Enregistrer'));
      await waitFor(
        tester,
        () => find.byType(JournalEditorSheet).evaluate().isEmpty,
        description: 'updated note',
      );
      expect(
        (await serverNotes()).single['content'],
        'Une petite pause m’a fait du bien.',
      );
      await tester.runAsync(() async {
        await Future.wait([
          services.chat.flushed,
          services.user.flushed,
          services.mascot.flushed,
        ]);
      });
      // Rebuild app state while retaining native Keychain and encrypted SQLite.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      app.main();
      await openJournal();
      services = tester
          .element(find.byType(JournalPage))
          .read<AppDependencies>();
      await waitFor(
        tester,
        () => services.journal.entries.any(
          (e) =>
              e.id == id && e.content == 'Une petite pause m’a fait du bien.',
        ),
        description: 'persisted journal after bootstrap',
      );
      await tapVisible(tester, find.text('Une pause pour moi').last);
      await waitFor(
        tester,
        () => find.byType(JournalEntryPage).evaluate().isNotEmpty,
        description: 'restored note reader',
      );
      expect(find.text('Une petite pause m’a fait du bien.'), findsOneWidget);
      debugPrint('JOURNAL_QA_FRAME_READY');
      if (const bool.fromEnvironment('HOLD_JOURNAL_QA_FRAME')) {
        await tester.pump(const Duration(milliseconds: 500));
        await Future<void>.delayed(const Duration(seconds: 25));
      }
      await tapVisible(tester, find.text('Supprimer'));
      await tapVisible(tester, find.text('Supprimer la note'));
      await waitFor(
        tester,
        () =>
            services.journal.entries.isEmpty &&
            find.byType(JournalEntryPage).evaluate().isEmpty,
        description: 'confirmed deletion',
      );
      expect(await serverNotes(), isEmpty);
      await tester.pump(const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
    },
  );
}
