import 'dart:convert';

import 'package:elyrii_app/app/app_dependencies.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:elyrii_app/features/meditation/data/repositories/meditation_repository.dart';
import 'package:elyrii_app/features/meditation/presentation/pages/meditation_session_page.dart';
import 'package:elyrii_app/features/meditation/presentation/widgets/meditation_library.dart';
import 'package:elyrii_app/features/meditation/presentation/widgets/meditation_summary_sheet.dart';
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
    'native meditation records breathing, summary mood and interrupted written guidance',
    (tester) async {
      const base = String.fromEnvironment('ELYRII_API_URL');
      expect(Uri.parse(base).host, '127.0.0.1');
      const password = 'MeditationNative123';
      final client = http.Client(), storage = SecureStorageService();
      final registered = await client.post(
        Uri.parse('$base/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': 'ios-meditation-${const Uuid().v4()}@example.test',
          'password': password,
          'firstName': 'Calme',
          'lastName': 'Fixture',
        }),
      );
      expect(registered.statusCode, 201, reason: registered.body);
      final session = jsonDecode(registered.body) as Map;
      final token = session['token'] as String;
      final owner =
          (jsonDecode(
                utf8.decode(
                  base64Url.decode(base64Url.normalize(token.split('.')[1])),
                ),
              ) as Map)['userId']
              as String;
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
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'password': password}),
        );
        expect(deleted.statusCode, 200, reason: deleted.body);
        await storage.clearAuthData();
        await storage.clearProfileSetup(owner);
        client.close();
      });

      Future<void> tap(Finder target) async {
        await tester.pump(const Duration(milliseconds: 450));
        await tapVisible(tester, target);
        await tester.pump(const Duration(milliseconds: 450));
      }

      app.main();
      await waitFor(
        tester,
        () => find.byType(DashboardPage).evaluate().isNotEmpty,
        description: 'authenticated app',
      );
      var services = tester
          .element(find.byType(DashboardPage))
          .read<AppDependencies>();
      tester.element(find.byType(DashboardPage)).go('/meditation');
      await waitFor(
        tester,
        () => find.byType(MeditationLibrary).evaluate().isNotEmpty,
        description: 'new meditation library',
      );
      await tap(find.byKey(const Key('meditation-featured')));
      expect(find.text('Commencer · 5 min'), findsOneWidget);
      await tap(find.text('Commencer · 5 min'));
      await waitFor(
        tester,
        () => find.byType(MeditationSessionPage).evaluate().isNotEmpty,
        description: 'native breathing session',
      );
      var controller = tester
          .widget<MeditationSessionPage>(find.byType(MeditationSessionPage))
          .controller;
      await waitFor(
        tester,
        () => controller.backendSessionId != null,
        description: 'acknowledged breathing registration',
      );
      expect(controller.backendError, isNull);
      final breathingId = controller.backendSessionId!;
      await tap(find.byTooltip('Mettre en pause'));
      final remaining = controller.remainingSeconds;
      await tester.pump(const Duration(seconds: 2));
      expect(controller.remainingSeconds, remaining);
      expect(find.text('En pause'), findsOneWidget);
      await tap(find.byTooltip('Reprendre'));
      expect(controller.isRunning, isTrue);
      await tap(find.text('Terminer la séance'));
      await waitFor(
        tester,
        () => find.byType(MeditationSummarySheet).evaluate().isNotEmpty,
        description: 'session summary',
      );
      await tap(find.bySemanticsLabel('Bien'));
      await tester.runAsync(() => controller.synchronized);
      expect(controller.backendError, isNull);
      final repository = MeditationRepository(client: services.api);
      final saved = (await tester.runAsync(() => repository.getSessions()))!
          .single;
      expect(saved.id, breathingId);
      expect(saved.type, 'coherence');
      expect(saved.durationMinutes, 5);
      expect(saved.status, 'COMPLETED');
      expect(saved.moodAfter, 'happy');
      debugPrint('MEDITATION_QA_FRAME_READY');
      if (const bool.fromEnvironment('HOLD_MEDITATION_QA_FRAME')) {
        await Future<void>.delayed(const Duration(seconds: 25));
      }
      await tap(find.text('Fermer'));
      await waitFor(
        tester,
        () =>
            find.byType(MeditationLibrary).evaluate().isNotEmpty &&
            find.byType(MeditationSessionPage).evaluate().isEmpty,
        description: 'return to library',
      );
      await tap(find.text('10 min').first);
      await tap(find.byKey(const Key('meditation-featured')));
      expect(find.text('Scan corporel'), findsWidgets);
      await tap(find.text('Commencer · 10 min'));
      await waitFor(
        tester,
        () => find.byType(MeditationSessionPage).evaluate().isNotEmpty,
        description: 'written session',
      );
      controller = tester
          .widget<MeditationSessionPage>(find.byType(MeditationSessionPage))
          .controller;
      await waitFor(
        tester,
        () => controller.backendSessionId != null,
        description: 'acknowledged written registration',
      );
      expect(
        find.byKey(const Key('meditation-guidance-instruction')),
        findsOneWidget,
      );
      final writtenId = controller.backendSessionId!;
      await tap(find.byTooltip('Fermer la séance'));
      await tap(find.text('Interrompre'));
      await tester.runAsync(() => controller.synchronized);
      final interrupted = (await tester.runAsync(
        () => repository.getSessions(),
      ))!.singleWhere((s) => s.id == writtenId);
      expect(interrupted.type, 'body-scan');
      expect(interrupted.durationMinutes, 10);
      expect(interrupted.status, 'CANCELED');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      app.main();
      await waitFor(
        tester,
        () => find.byType(DashboardPage).evaluate().isNotEmpty,
        description: 'restored native app',
      );
      services = tester
          .element(find.byType(DashboardPage))
          .read<AppDependencies>();
      final restored = (await tester.runAsync(
        () => MeditationRepository(client: services.api).getSessions(),
      ))!;
      expect(restored, hasLength(2));
      expect(
        restored.singleWhere((s) => s.id == breathingId).moodAfter,
        'happy',
      );
      expect(restored.singleWhere((s) => s.id == writtenId).status, 'CANCELED');
      final stats = await tester.runAsync(
        () => services.api.get('$base/user/stats?range=30d'),
      ) as Map;
      expect(stats['meditationSessionsCount'], 1);
      expect(tester.takeException(), isNull);
    },
  );
}
