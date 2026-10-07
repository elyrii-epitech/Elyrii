import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart' show TextField;
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:elyrii_app/main.dart' as app;
import 'package:elyrii_app/app/app_dependencies.dart';
import 'package:elyrii_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:elyrii_app/features/chatbot/presentation/pages/chatbot_page.dart';
import 'package:elyrii_app/features/meditation/presentation/pages/meditation_page.dart';
import 'package:elyrii_app/core/widgets/glass_navigation_bar.dart';
import 'package:elyrii_app/core/widgets/glass_bubble_button.dart';

/// Runs with real secure storage, SQLite and mascot platform views on a device.
/// The demo fixture does not require production credentials or an AI backend.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real bootstrap, restored demo and primary navigation', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    app.main();
    final limit = DateTime.now().add(const Duration(seconds: 45));
    while (find.text('Découvrir Elyrii').evaluate().isEmpty &&
        find.byType(DashboardPage).evaluate().isEmpty &&
        DateTime.now().isBefore(limit)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (find.text('Découvrir Elyrii').evaluate().isNotEmpty) {
      await tester.tap(find.text('Découvrir Elyrii'));
      for (
        var i = 0;
        i < 30 && find.byType(DashboardPage).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 250));
      }
    }
    expect(find.byType(DashboardPage), findsOneWidget);
    expect(find.byType(GlassNavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await binding.traceAction(() async {
      await tester.tap(find.byType(GlassBubbleButtonStateful));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(ChatbotPage), findsOneWidget);
      final services = tester
          .element(find.byType(ChatbotPage))
          .read<AppDependencies>();
      await tester.runAsync(() => services.chat.ready);
      const message = 'Native integration persistence fixture';
      await tester.enterText(find.byType(TextField).last, message);
      await tester.tap(find.byTooltip('Envoyer le message'));
      await tester.pump();
      await tester.runAsync(() => services.chat.flushed);
      final messages = await tester.runAsync(
        () => services.history.messages(
          services.auth.accountId!,
          services.chat.activeSessionId!,
        ),
      );
      expect(
        messages!.any((item) => item.isUser && item.content == message),
        isTrue,
      );
      await tester.runAsync(() => services.chat.disconnect());
      await tester.tap(
        find.bySemanticsLabel(RegExp(r'^Onglet Méditation,')).first,
      );
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(MeditationPage), findsOneWidget);
    }, reportKey: 'frontend_navigation');
    expect(tester.takeException(), isNull);
  });
}
