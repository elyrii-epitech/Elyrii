import 'package:elyrii_app/core/glass/elyrii_glass_surface.dart';
import 'package:elyrii_app/core/theme/app_colors.dart';
import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/core/widgets/accessible_action.dart';
import 'package:elyrii_app/features/chatbot/presentation/widgets/typing_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('error text/background pairs meet 4.5:1 contrast in both themes', () {
    for (final scheme in [
      AppTheme.lightTheme.colorScheme,
      AppTheme.darkTheme.colorScheme,
    ]) {
      final l1 = scheme.error.computeLuminance();
      final l2 = scheme.onError.computeLuminance();
      expect(
        (l1 > l2 ? (l1 + .05) / (l2 + .05) : (l2 + .05) / (l1 + .05)),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
  testWidgets(
    'high-contrast glass uses an opaque surface even with a translucent tint',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(highContrast: true),
            child: ElyriiGlassSurface(
              role: GlassRole.dialog,
              glassColor: AppColors.primary.withValues(alpha: .2),
              child: const Text('Content'),
            ),
          ),
        ),
      );
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(ElyriiGlassSurface),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((container.decoration as BoxDecoration).color!.a, 1);
    },
  );
  testWidgets(
    'shared actions work with keyboard and expose one explicit label',
    (tester) async {
      var activated = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleAction(
              label: 'Ouvrir la note',
              onPressed: () => activated++,
              child: const SizedBox(
                width: 100,
                height: 50,
                child: Text('Note'),
              ),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(activated, 1);
      expect(find.bySemanticsLabel('Ouvrir la note'), findsOneWidget);
    },
  );
  testWidgets('reduced-motion typing indicator leaves no repeating ticker', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: TypingIndicator()),
        ),
      ),
    );
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
  });
}
