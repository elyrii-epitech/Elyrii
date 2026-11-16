import 'dart:convert';

import 'package:elyrii_app/app/app_dependencies.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:elyrii_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:elyrii_app/features/gamification/presentation/pages/challenges_page.dart';
import 'package:elyrii_app/features/gamification/presentation/widgets/monthly_garden.dart';
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
    'native challenges accept, reject, start and grow the persisted garden from mood actions',
    (tester) async {
      const base = String.fromEnvironment('ELYRII_API_URL');
      expect(Uri.parse(base).host, '127.0.0.1');
      const password = 'ChallengeNative123';
      final client = http.Client(), storage = SecureStorageService();
      final registered = await client.post(
        Uri.parse('$base/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': 'ios-challenges-${const Uuid().v4()}@example.test',
          'password': password,
          'firstName': 'Jardin',
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
      for (final title in ['Deux petits pas', 'Une autre suggestion']) {
        final proposal = await client.post(
          Uri.parse('$base/challenge/proposals'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'title': title,
            'description':
                'Enregistre deux humeurs pour voir grandir ton jardin.',
            'conditions': [
              {'type': 'mood_count', 'target': 2},
            ],
            'aggregator': 'ALL',
          }),
        );
        expect(proposal.statusCode, 201, reason: proposal.body);
      }
      Future<void> tap(Finder target) async {
        await waitFor(
          tester,
          () => target.evaluate().isNotEmpty,
          description: 'challenge action to appear',
        );
        // ExpansionTile lays out its children before the reveal animation has
        // finished; scroll using the final viewport geometry.
        await tester.pump(const Duration(milliseconds: 500));
        await Scrollable.ensureVisible(
          tester.element(target.first),
          alignment: .5,
        );
        await tester.pump(const Duration(milliseconds: 250));
        await waitFor(
          tester,
          () => target.hitTestable().evaluate().isNotEmpty,
          description: 'challenge action to accept taps',
        );
        await tester.tap(target.hitTestable().first);
        await tester.pump();
      }

      Finder action(String title, String label) {
        final card = find
            .ancestor(of: find.text(title), matching: find.byType(Material))
            .first;
        return find.descendant(of: card, matching: find.text(label));
      }

      Future<void> openChallenges() async {
        final page = find.byType(DashboardPage).evaluate().isNotEmpty
            ? find.byType(DashboardPage)
            : find.byType(ChallengesPage);
        tester.element(page).go('/challenges');
        await waitFor(
          tester,
          () => find.byType(ChallengesPage).evaluate().isNotEmpty,
          description: 'challenges tab',
        );
        await tester.pump(const Duration(milliseconds: 300));
      }

      Future<void> mood(
        String label,
        MoodType expected,
        AppDependencies services,
      ) async {
        tester.element(find.byType(ChallengesPage)).go('/');
        await waitFor(
          tester,
          () => find.byType(DashboardPage).evaluate().isNotEmpty,
          description: 'dashboard mood action',
        );
        await tap(find.bySemanticsLabel(label));
        await waitFor(
          tester,
          () =>
              services.dashboard.selectedMood == expected &&
              !services.dashboard.isSavingMood,
          description: 'confirmed mood',
        );
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
      await waitFor(
        tester,
        () =>
            services.gamification.proposals.length == 2 &&
            !services.gamification.isLoading,
        description: 'real proposals',
      );
      await openChallenges();
      await tap(action('Deux petits pas', 'Accepter'));
      await waitFor(
        tester,
        () => services.gamification.activeChallenges.length == 1,
        description: 'accepted proposal',
      );
      await tap(action('Une autre suggestion', 'Refuser'));
      await waitFor(
        tester,
        () => services.gamification.proposals.isEmpty,
        description: 'rejected proposal',
      );
      await tap(find.textContaining('Idées de défis ('));
      await tap(action('Premier pas', 'Commencer'));
      await waitFor(
        tester,
        () => services.gamification.activeChallenges.length == 2,
        description: 'started system challenge',
      );

      await mood('Bien', MoodType.happy, services);
      await waitFor(
        tester,
        () =>
            services.gamification.completedChallenges.length == 1 &&
            services.gamification.activeChallenges.single.progressFraction ==
                .5,
        description: 'server-backed half progress',
      );
      await openChallenges();
      expect(find.text('1 / 2'), findsOneWidget);
      await mood('Bof', MoodType.neutral, services);
      await waitFor(
        tester,
        () =>
            services.gamification.completedChallenges.length == 2 &&
            services.gamification.activeChallenges.isEmpty &&
            !services.gamification.isLoading,
        description: 'two completed challenges',
      );
      await openChallenges();
      expect(
        tester.widget<MonthlyGarden>(find.byType(MonthlyGarden)).flowers.length,
        greaterThanOrEqualTo(2),
      );
      await tester.runAsync(() async {
        await services.dashboard.refresh();
        await Future.wait([
          services.chat.flushed,
          services.user.flushed,
          services.mascot.flushed,
        ]);
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      app.main();
      await waitFor(
        tester,
        () => find.byType(DashboardPage).evaluate().isNotEmpty,
        description: 'restored app',
      );
      services = tester
          .element(find.byType(DashboardPage))
          .read<AppDependencies>();
      await waitFor(
        tester,
        () =>
            services.gamification.completedChallenges.length == 2 &&
            !services.gamification.isLoading,
        description: 'persisted garden',
      );
      await openChallenges();
      final garden = tester.widget<MonthlyGarden>(find.byType(MonthlyGarden));
      expect(
        garden.flowers.map((flower) => flower.title),
        containsAll(['Premier pas', 'Deux petits pas']),
      );
      await Scrollable.ensureVisible(
        tester.element(find.byType(MonthlyGarden)),
        alignment: .5,
      );
      await tester.pump(const Duration(seconds: 1));
      debugPrint('CHALLENGES_QA_FRAME_READY');
      if (const bool.fromEnvironment('HOLD_CHALLENGES_QA_FRAME')) {
        await Future<void>.delayed(const Duration(seconds: 20));
      }
      expect(tester.takeException(), isNull);
    },
  );
}
