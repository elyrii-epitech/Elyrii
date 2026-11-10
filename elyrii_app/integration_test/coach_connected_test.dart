import 'dart:convert';

import 'package:elyrii_app/app/app_dependencies.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:elyrii_app/features/journal/presentation/widgets/journal_editor_sheet.dart';
import 'package:elyrii_app/features/meditation/presentation/pages/meditation_session_page.dart';
import 'package:elyrii_app/features/meditation/presentation/widgets/meditation_summary_sheet.dart';
import 'package:elyrii_app/features/parcours/domain/journey.dart';
import 'package:elyrii_app/features/parcours/presentation/pages/parcours_page.dart';
import 'package:elyrii_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'support/native_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native Coach connects program steps, meditation, journal and restored account progress',
    (tester) async {
      const base = String.fromEnvironment('ELYRII_API_URL');
      expect(Uri.parse(base).host, '127.0.0.1');
      const password = 'CoachNative123';
      final client = http.Client(), storage = SecureStorageService();
      final registered = await client.post(
        Uri.parse('$base/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': 'ios-coach-${const Uuid().v4()}@example.test',
          'password': password,
          'firstName': 'Coach',
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
        await tester.pump(const Duration(milliseconds: 500));
        await tapVisible(tester, target);
        await tester.pump(const Duration(milliseconds: 500));
      }

      Future<Map> serverJourney() async {
        final response = await client.get(
          Uri.parse('$base/coach/journey'),
          headers: {'Authorization': 'Bearer $token'},
        );
        expect(response.statusCode, 200, reason: response.body);
        return (jsonDecode(response.body) as Map)['current'] as Map;
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
      tester.element(find.byType(DashboardPage)).go('/parcours');
      await waitFor(
        tester,
        () => services.parcours.hasLoadedData && !services.parcours.isLoading,
        description: 'server Coach catalogue',
      );
      expect(services.parcours.error, isNull);
      expect(services.parcours.current, isNull);
      await tap(find.text('Faire une pause'));
      await tap(find.text('Choisir ce programme'));
      await waitFor(
        tester,
        () => services.parcours.current != null && !services.parcours.isWriting,
        description: 'confirmed program choice',
      );
      final enrollmentId = services.parcours.current!.enrollmentId;
      await tap(find.text('Continuer'));
      await tap(find.text('Ouvrir Souffle conscient'));
      await tap(find.text('Commencer · 3 min'));
      await waitFor(
        tester,
        () => find.byType(MeditationSessionPage).evaluate().isNotEmpty,
        description: 'Coach meditation link',
      );
      final meditation = tester
          .widget<MeditationSessionPage>(find.byType(MeditationSessionPage))
          .controller;
      await waitFor(
        tester,
        () => meditation.backendSessionId != null,
        description: 'registered linked meditation',
      );
      await tap(find.text('Terminer la séance'));
      await waitFor(
        tester,
        () => find.byType(MeditationSummarySheet).evaluate().isNotEmpty,
        description: 'linked meditation summary',
      );
      await tap(find.bySemanticsLabel('Bien'));
      await tester.runAsync(() => meditation.synchronized);
      expect(meditation.backendError, isNull);
      await tap(find.text('Fermer'));
      await waitFor(
        tester,
        () =>
            find.text('Terminer l’étape').evaluate().isNotEmpty &&
            find.byType(MeditationSessionPage).evaluate().isEmpty,
        description: 'return to the same Coach step',
      );
      expect(services.parcours.current!.completedStepCount, 0);
      await tap(find.text('Terminer l’étape'));
      await waitFor(
        tester,
        () =>
            services.parcours.current!.completedStepCount == 1 &&
            !services.parcours.isWriting,
        description: 'confirmed first step',
      );
      await tap(find.text('Mettre en pause'));
      await waitFor(
        tester,
        () =>
            services.parcours.current!.status == JourneyStatus.paused &&
            !services.parcours.isWriting,
        description: 'paused program',
      );
      expect(find.text('Ton programme est en pause'), findsOneWidget);
      expect((await tester.runAsync(serverJourney))!['status'], 'paused');
      await tap(find.text('Reprendre'));
      await waitFor(
        tester,
        () =>
            services.parcours.current!.status == JourneyStatus.active &&
            !services.parcours.isWriting,
        description: 'resumed at same step',
      );
      await tap(find.text('Continuer'));
      await tap(find.text('Ouvrir mon Journal'));
      await waitFor(
        tester,
        () => find.byType(JournalEditorSheet).evaluate().isNotEmpty,
        description: 'linked Journal editor',
      );
      await tester.enterText(
        find.byType(TextField).at(0),
        'Une pause avec Coach',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'J’ai pris le temps d’observer mon souffle puis d’écrire ces mots.',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tap(find.text('Enregistrer'));
      await waitFor(
        tester,
        () =>
            find.byType(JournalEditorSheet).evaluate().isEmpty &&
            services.journal.entries.isNotEmpty,
        description: 'confirmed linked Journal note',
      );
      expect(services.parcours.current!.completedStepCount, 1);
      await tap(find.text('Terminer l’étape'));
      await waitFor(
        tester,
        () =>
            services.parcours.current!.status == JourneyStatus.completed &&
            !services.parcours.isWriting,
        description: 'completed Coach program',
      );
      expect(find.text('Programme terminé'), findsOneWidget);
      final completed = (await tester.runAsync(serverJourney))!;
      expect(completed['enrollmentId'], enrollmentId);
      expect(completed['completedStepCount'], 2);
      expect(completed['status'], 'completed');
      await Scrollable.ensureVisible(
        tester.element(find.text('Programme terminé')),
        alignment: .3,
      );
      await tester.pump(const Duration(milliseconds: 500));
      debugPrint('COACH_QA_FRAME_READY');
      if (const bool.fromEnvironment('HOLD_COACH_QA_FRAME')) {
        await Future<void>.delayed(const Duration(seconds: 25));
      }
      await tap(find.text('Changer de programme'));
      await tap(find.text('Garder le contact'));
      await tap(find.text('Choisir ce programme'));
      await tap(find.text('Confirmer le changement'));
      await waitFor(
        tester,
        () =>
            services.parcours.current!.path.pathId ==
                'connection-small-steps' &&
            !services.parcours.isWriting,
        description: 'confirmed replacement program',
      );
      final replacementId = services.parcours.current!.enrollmentId;
      expect(replacementId, isNot(enrollmentId));
      await tester.runAsync(() async {
        await Future.wait([
          services.parcours.flushed,
          services.user.flushed,
          services.chat.flushed,
          services.mascot.flushed,
        ]);
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      // Prove restoration from the backend after removing only this fixture's
      // cached journey, rather than reading the same preferences again.
      await (await SharedPreferences.getInstance()).remove(
        'journey_progress_${Uri.encodeComponent(owner)}',
      );
      app.main();
      await waitFor(
        tester,
        () => find.byType(DashboardPage).evaluate().isNotEmpty,
        description: 'restored native app',
      );
      services = tester
          .element(find.byType(DashboardPage))
          .read<AppDependencies>();
      tester.element(find.byType(DashboardPage)).go('/parcours');
      await waitFor(
        tester,
        () =>
            find.byType(ParcoursPage).evaluate().isNotEmpty &&
            services.parcours.hasLoadedData &&
            !services.parcours.isLoading,
        description: 'remote progress without a device cache',
      );
      expect(services.parcours.error, isNull);
      expect(services.parcours.current!.enrollmentId, replacementId);
      expect(services.parcours.current!.completedStepCount, 0);
      expect(find.text('Garder le contact'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
