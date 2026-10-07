import 'package:flutter_test/flutter_test.dart';

import 'package:elyrii_app/core/widgets/launch_scope.dart';
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
  await waitFor(
    tester,
    () => target.evaluate().isNotEmpty,
    description: '$target to appear',
  );
  await tester.ensureVisible(target);
  await waitFor(
    tester,
    () => target.hitTestable().evaluate().isNotEmpty,
    description: '$target to accept taps',
  );
  await tester.tap(target.hitTestable());
  await tester.pump();
}

/// Uses the real bootstrap and demo button, including the launch overlay and
/// scrolling needed to reach the button on smaller native screens.
Future<void> startDemoApp(WidgetTester tester) async {
  app.main();
  await waitFor(
    tester,
    () => find
        .byType(LaunchScope)
        .evaluate()
        .any((element) => !(element.widget as LaunchScope).isRevealing),
    description: 'native bootstrap and launch reveal',
  );
  if (find.byType(DashboardPage).evaluate().isEmpty) {
    await tapVisible(tester, find.text('Découvrir Elyrii'));
  }
  await waitFor(
    tester,
    () => find.byType(DashboardPage).evaluate().isNotEmpty,
    description: 'the demo dashboard',
  );
}
