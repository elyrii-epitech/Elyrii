import 'dart:convert';

import 'package:elyrii_app/app/app_dependencies.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/storage/content_cipher.dart';
import 'package:elyrii_app/features/dashboard/data/accueil_activities.dart';
import 'package:elyrii_app/features/dashboard/domain/civil_day.dart';
import 'package:elyrii_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:elyrii_app/features/journal/presentation/pages/journal_page.dart';
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
    'native Home preserves its design while syncing activities, questions and scene',
    (tester) async {
      const base = String.fromEnvironment('ELYRII_API_URL');
      expect(Uri.parse(base).host, '127.0.0.1');
      const password = 'HomeNative123';
      final client = http.Client(), storage = SecureStorageService();
      final registered = await client.post(
        Uri.parse('$base/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': 'ios-home-${const Uuid().v4()}@example.test',
          'password': password,
          'firstName': 'Home',
          'lastName': 'Fixture',
        }),
      );
      expect(registered.statusCode, 201, reason: registered.body);
      final session = jsonDecode(registered.body) as Map,
          token = session['token'] as String;
      final owner =
          (jsonDecode(
                utf8.decode(
                  base64Url.decode(base64Url.normalize(token.split('.')[1])),
                ),
              ) as Map)['userId']
              as String;
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      await storage.saveAccessToken(token);
      await storage.saveRefreshToken(session['refreshToken'] as String);
      await storage.saveUserId(owner);
      await storage.setProfileSetupCompleted();
      final today = CivilDay.fromLocal(DateTime.now()),
          monday = AccueilActivities.mondayOf(
            CivilDay.fromLocal(DateTime.now()),
          );
      final legacy = AccueilActivities(cipher: ContentCipher(storage));
      legacy.onUserChanged(userId: owner);
      await legacy.flushed;
      await legacy.setRitualDone(
        day: today,
        ritual: AccueilRitual.walk,
        done: true,
      );
      await legacy.setDecor(MascotDecor.hills, completedChallenges: 0);
      await legacy.flushed;
      legacy.dispose();
      final note = await client.post(
        Uri.parse('$base/journal'),
        headers: headers,
        body: jsonEncode({
          'title': 'Une pause pour moi',
          'content': 'Une note fictive pour le suivi de l’Accueil.',
        }),
      );
      expect(note.statusCode, 201, reason: note.body);
      final entryId = (jsonDecode(note.body) as Map)['body']['id'] as String;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        final response = await client.delete(
          Uri.parse('$base/user/account'),
          headers: headers,
          body: jsonEncode({'password': password}),
        );
        expect(response.statusCode, 200, reason: response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('accueil_activities_$owner');
        await prefs.remove('accueil_activities_legacy_$owner');
        await storage.clearAuthData();
        await storage.clearProfileSetup(owner);
        await ContentCipher(storage).deleteOwner(owner);
        client.close();
      });
      Future<void> tap(Finder target) async {
        await tester.pump(const Duration(milliseconds: 500));
        if (target.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            target,
            220,
            scrollable: find.byType(Scrollable).first,
          );
        }
        await waitFor(
          tester,
          () => target.evaluate().isNotEmpty,
          description: 'Home control to appear',
        );
        await Scrollable.ensureVisible(
          tester.element(target.first),
          alignment: .5,
        );
        await tester.pump(const Duration(milliseconds: 400));
        await waitFor(
          tester,
          () => target.hitTestable().evaluate().isNotEmpty,
          description: 'Home control to accept taps',
        );
        await tester.tap(target.hitTestable().first);
        await tester.pump(const Duration(milliseconds: 500));
      }

      Future<Map> serverHome() async {
        final response = await client.get(
          Uri.parse('$base/user/home'),
          headers: headers,
        );
        expect(response.statusCode, 200, reason: response.body);
        return (jsonDecode(response.body) as Map)['activities'] as Map;
      }

      app.main();
      await waitFor(
        tester,
        () => find.byType(DashboardPage).evaluate().isNotEmpty,
        description: 'authenticated Home',
      );
      var services = tester
          .element(find.byType(DashboardPage))
          .read<AppDependencies>();
      Future<void> saved() async {
        await waitFor(
          tester,
          () =>
              !services.accueilActivities.snapshot.isLoading &&
              !services.accueilActivities.snapshot.isWriting,
          description: 'confirmed Home activity',
        );
        expect(services.accueilActivities.snapshot.error, isNull);
      }

      await saved();
      await waitFor(
        tester,
        () => services.journal.entries.any((entry) => entry.id == entryId),
        description: 'owned follow-up journal note',
      );
      expect(
        services.journal.entries
            .singleWhere((entry) => entry.id == entryId)
            .createdAt
            .isAfter(DateTime.now().add(const Duration(seconds: 2))),
        isFalse,
        reason: 'Fixture journal timestamps must use UTC',
      );
      expect(services.accueilActivities.snapshot.decor, MascotDecor.hills);
      expect(
        services.accueilActivities.snapshot.rituals[today]!.isDone(
          AccueilRitual.walk,
        ),
        isTrue,
      );
      await tap(find.bySemanticsLabel('Décocher Marcher 10 minutes'));
      await saved();
      await tap(find.bySemanticsLabel('Cocher Respirer 2 minutes'));
      await saved();
      await tap(find.text('Plutôt bien'));
      await saved();
      await tap(find.text('Une autre idée'));
      await saved();
      await tap(find.text('C’est fait'));
      await saved();
      final activities = (await tester.runAsync(serverHome))!;
      expect(
        activities['ritualDays'][today.isoDate].containsKey('walk'),
        isFalse,
      );
      expect(activities['ritualDays'][today.isoDate]['breathe'], isNotNull);
      expect(activities['threadAnswers'][entryId]['reply'], 'ratherGood');
      expect(activities['socialWeeks'][monday.isoDate]['ideaIndex'], 1);
      expect(
        activities['socialWeeks'][monday.isoDate]['completedAt'][today.isoDate],
        isNotNull,
      );
      tester.element(find.byType(DashboardPage)).go('/journal');
      await waitFor(
        tester,
        () => find.byType(JournalPage).evaluate().isNotEmpty,
        description: 'Journal question picker',
      );
      await tap(find.byTooltip('Changer la question'));
      await saved();
      final pick = services.accueilActivities.snapshot.journalQuestion;
      expect(pick, isNotNull);
      tester.element(find.byType(JournalPage)).go('/');
      await waitFor(
        tester,
        () => find.byType(DashboardPage).evaluate().isNotEmpty,
        description: 'return to Home',
      );
      await saved();
      // The scene selector is in the unchanged Home dressing panel.
      final homeScroll = find.descendant(
        of: find.byKey(const PageStorageKey('accueil-scroll')),
        matching: find.byType(Scrollable),
      );
      tester.state<ScrollableState>(homeScroll).position.jumpTo(0);
      await tester.pump(const Duration(milliseconds: 500));
      await tap(find.bySemanticsLabel('Personnaliser Elyrii'));
      await tap(find.text('Décor'));
      await tap(find.bySemanticsLabel('Vagues'));
      await tap(find.byKey(const ValueKey('save_mascot_look')));
      await waitFor(
        tester,
        () => find.text('Apparence d’Elyrii').evaluate().isEmpty,
        description: 'confirmed scene save',
      );
      await saved();
      expect((await tester.runAsync(serverHome))!['decor'], 'waves');
      await tester.runAsync(() async {
        await Future.wait([
          services.accueilActivities.flushed,
          services.user.flushed,
          services.chat.flushed,
          services.mascot.flushed,
        ]);
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await (await SharedPreferences.getInstance()).remove(
        'accueil_activities_$owner',
      );
      app.main();
      await waitFor(
        tester,
        () => find.byType(DashboardPage).evaluate().isNotEmpty,
        description: 'restored Home without device cache',
      );
      services = tester
          .element(find.byType(DashboardPage))
          .read<AppDependencies>();
      await saved();
      final restored = services.accueilActivities.snapshot;
      expect(restored.decor, MascotDecor.waves);
      expect(restored.rituals[today]!.isDone(AccueilRitual.breathe), isTrue);
      expect(restored.rituals[today]!.isDone(AccueilRitual.walk), isFalse);
      expect(restored.threadAnswers[entryId]!.reply, ThreadReply.ratherGood);
      expect(restored.socialWeeks[monday]!.isDone(today), isTrue);
      expect(restored.journalQuestion!.index, pick!.index);
      debugPrint('HOME_NATIVE_RESTORE_VERIFIED');
      await Scrollable.ensureVisible(
        tester.element(find.text('Activités du jour')),
        alignment: .35,
      );
      await tester.pump(const Duration(milliseconds: 500));
      debugPrint('HOME_QA_FRAME_READY');
      if (const bool.fromEnvironment('HOLD_HOME_QA_FRAME')) {
        await Future<void>.delayed(const Duration(seconds: 35));
      }
      expect(tester.takeException(), isNull);
    },
  );
}
