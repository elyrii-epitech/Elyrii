import 'package:elyrii_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:elyrii_app/features/profile_setup/presentation/pages/profile_setup_page.dart';
import 'package:elyrii_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../support/accessibility_fixture.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Poppins')
          ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Poppins-Medium.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Poppins-Bold.ttf')))
        .load();
  });

  testWidgets('guest onboarding renders every step and reaches the dashboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await initializeDateFormatting('fr');
    final services = (await tester.runAsync(fixture))!;
    services.profileSetupDone.value = false;
    try {
      await tester.pumpWidget(
        host(
          services,
          MyApp(
            authProvider: services.auth,
            profileSetupDoneListenable: services.profileSetupDone,
          ),
          GlobalKey(),
          false,
          1,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ProfileSetupPage), findsOneWidget);
      for (var step = 0; step < 3; step++) {
        final skip = find.text('Passer');
        await tester.ensureVisible(skip);
        await tester.pump();
        await tester.tap(skip);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull, reason: 'Step ${step + 2}');
      }
      final enter = find.text('Entrer dans Elyrii');
      await tester.ensureVisible(enter);
      await tester.pump();
      await tester.tap(enter);
      for (
        var attempt = 0;
        attempt < 50 && find.byType(DashboardPage).evaluate().isEmpty;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(DashboardPage), findsOneWidget);
      expect(services.profileSetupDone.value, isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      visualJournals.remove(services)!.dispose();
      await tester.runAsync(() async {
        services.dispose();
        await services.chat.flushed;
        await services.history.close();
        await services.journalStore.close();
      });
    }
  });
}
