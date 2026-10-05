import 'package:elyrii_app/core/widgets/mascot_bounce.dart';
import 'package:elyrii_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:elyrii_app/features/dashboard/presentation/widgets/mascot_peek.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Rejoue le rebond : doit écraser puis overshoot avant retour au repos.
double _scaleOf(WidgetTester tester) {
  final transition = tester.widget<ScaleTransition>(
    find
        .descendant(
          of: find.byType(MascotBounce),
          matching: find.byType(ScaleTransition),
        )
        .first,
  );
  return transition.scale.value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MascotBounce', () {
    testWidgets('rebond rejoué quand le trigger augmente, puis repos', (
      tester,
    ) async {
      int trigger = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: MascotBounce(
                trigger: trigger,
                child: const SizedBox(width: 100, height: 100),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () => setState(() => trigger++),
              ),
            ),
          ),
        ),
      );

      expect(_scaleOf(tester), 1.0);

      await tester.tap(find.byType(FloatingActionButton));
      // Frame 1 : déclenche didUpdateWidget (démarrage du contrôleur) ;
      // frame 2 : fait avancer l'animation dans la phase squash.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      // Phase squash : légèrement écrasé.
      expect(_scaleOf(tester), lessThan(1.0));

      await tester.pumpAndSettle();
      // Repos : scale exactement 1.
      expect(_scaleOf(tester), moreOrLessEquals(1.0));
    });

    testWidgets('pas de rebond sans nouvelle incrémentation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MascotBounce(
              trigger: 5,
              child: SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 80));

      expect(_scaleOf(tester), 1.0);
    });
  });

  group('MascotPeek', () {
    testWidgets('tap sur la mascotte déclenche le rebond', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => MascotProvider(),
          child: const MaterialApp(home: Scaffold(body: MascotPeek())),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byType(MascotPeek));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(_scaleOf(tester), lessThan(1.0));
      await tester.pumpAndSettle();
      expect(_scaleOf(tester), moreOrLessEquals(1.0));
    });

    testWidgets('sélection d\'humeur déclenche le rebond', (tester) async {
      final mood = ValueNotifier<MoodType?>(null);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => MascotProvider(),
          child: MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<MoodType?>(
                valueListenable: mood,
                builder: (context, value, _) => MascotPeek(selectedMood: value),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      mood.value = MoodType.happy;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(_scaleOf(tester), lessThan(1.0));
      await tester.pumpAndSettle();
      expect(_scaleOf(tester), moreOrLessEquals(1.0));
    });
  });
}
