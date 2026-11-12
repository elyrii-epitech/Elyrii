import 'dart:ui' show SemanticsAction;

import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/core/widgets/glass/liquid_glass_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('touch, clavier et lecteur d’écran activent la même action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Center(
              child: LiquidGlassButton(
                label: 'Enregistrer mon look',
                onPressed: () => calls++,
              ),
            ),
          ),
        ),
      );
      final target = find.bySemanticsLabel('Enregistrer mon look');
      expect(target, findsOneWidget);
      await tester.tap(target);
      expect(calls, 1);
      Focus.of(tester.element(find.text('Enregistrer mon look')))
          .requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(calls, 3);
      final node = tester.getSemantics(target);
      node.owner!.performAction(node.id, SemanticsAction.tap);
      expect(calls, 4);
    } finally {
      semantics.dispose();
    }
  });

  for (final loading in [false, true]) {
    testWidgets('bouton inactif sans double envoi, chargement=$loading', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        var calls = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Center(
                child: LiquidGlassButton(
                  label: 'Enregistrer mon look',
                  isLoading: loading,
                  onPressed: loading ? () => calls++ : null,
                ),
              ),
            ),
          ),
        );
        final target = find.bySemanticsLabel('Enregistrer mon look');
        expect(
          tester
              .getSemantics(target)
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isFalse,
        );
        await tester.tap(target);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(calls, 0);
      } finally {
        semantics.dispose();
      }
    });
  }
}
