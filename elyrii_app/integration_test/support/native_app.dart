import 'package:flutter_test/flutter_test.dart';

import 'package:elyrii_app/features/auth/presentation/pages/login_page.dart';
import 'package:elyrii_app/features/profile_setup/presentation/pages/profile_setup_page.dart';
import 'package:elyrii_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:elyrii_app/main.dart' as app;

/// Waits for a specific state without settling the app's repeating animations.
Future<void> waitFor(
  WidgetTester tester,
  bool Function() condition, {
  required String description,
  Duration timeout = const Duration(seconds: 45),
}) async {
  final elapsed = Stopwatch()..start();
  while (!condition()) {
    if (elapsed.elapsed >= timeout) {
      fail('Timed out waiting for $description.');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapVisible(WidgetTester tester, Finder target) async {
  final description = target.describeMatch(Plurality.many);
  await waitFor(
    tester,
    () => target.evaluate().isNotEmpty,
    description: '$description to appear',
  );
  await tester.ensureVisible(target.first);
  await tester.pump();
  await waitFor(
    tester,
    () => target.hitTestable().evaluate().isNotEmpty,
    description: '$description to accept taps',
  );
  await tester.tap(target.hitTestable().first);
  await tester.pump();
}

/// Uses the real bootstrap and guest onboarding on native screens.
Future<void> startDemoApp(WidgetTester tester) async {
  app.main();
  await waitFor(
    tester,
    () =>
        find.byType(LoginPage).evaluate().isNotEmpty ||
        find.byType(DashboardPage).evaluate().isNotEmpty,
    description: 'native bootstrap',
  );
  if (find.byType(DashboardPage).evaluate().isEmpty) {
    await tapVisible(tester, find.bySemanticsLabel('Commencer'));
    await tapVisible(tester, find.text('Essayer la démo'));
    await waitFor(
      tester,
      () => find.byType(ProfileSetupPage).evaluate().isNotEmpty,
      description: 'guest onboarding',
    );
    for (var step = 0; step < 3; step++) {
      await tapVisible(tester, find.text('Passer'));
    }
    await tapVisible(tester, find.text('Commencer'));
  }
  await waitFor(
    tester,
    () => find.byType(DashboardPage).evaluate().isNotEmpty,
    description: 'the interactive demo dashboard',
  );
}
