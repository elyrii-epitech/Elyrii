import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/features/meditation/presentation/controllers/meditation_controller.dart';
import 'package:elyrii_app/features/meditation/presentation/widgets/meditation_library.dart';
import 'package:elyrii_app/features/meditation/presentation/widgets/meditation_duration_capsule.dart';
import 'package:elyrii_app/features/meditation/presentation/widgets/meditation_practice_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpLibrary(
  WidgetTester tester,
  MeditationController controller, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(body: MeditationLibrary(controller: controller)),
    ),
  );
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('Poppins')
      ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-Bold.ttf'));
    await loader.load();
  });
  testWidgets('la durée filtre les pratiques et la mise en avant', (
    tester,
  ) async {
    final controller = MeditationController();
    addTearDown(controller.dispose);
    await pumpLibrary(tester, controller);
    final capsule = find.byType(MeditationDurationCapsule);
    expect(tester.getTopLeft(capsule).dy, 234);
    await tester.drag(
      find.byKey(const Key('meditation-library-scroll')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(capsule).dy, 58);
    expect(find.text('Scan corporel'), findsWidgets);
    await tester.tap(find.text('3 min'));
    await tester.pump();
    expect(find.text('Scan corporel'), findsNothing);
    expect(find.text('Cohérence cardiaque'), findsNothing);
    expect(find.text('Expiration longue'), findsWidgets);
    await tester.tap(find.text('15 min'));
    await tester.pump();
    expect(find.text('Découverte'), findsNothing);
    expect(find.text('Relaxation 4-7-8'), findsNothing);
    expect(find.text('Cohérence cardiaque'), findsWidgets);
    expect(controller.isSetup, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'la carte centrée conserve le rythme réel et la durée de la capsule',
    (tester) async {
      final controller = MeditationController();
      addTearDown(controller.dispose);
      await pumpLibrary(tester, controller);
      await tester.tap(find.text('15 min'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('meditation-featured')));
      await tester.pumpAndSettle();
      final preview = find.byType(MeditationPracticePreview);
      expect(
        find.descendant(of: preview, matching: find.text('5 · 5')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: preview, matching: find.text('3 min')),
        findsNothing,
      );
      expect(
        tester
            .getCenter(
              find
                  .descendant(of: preview, matching: find.byType(Material))
                  .first,
            )
            .dy,
        422,
      );
      await tester.tap(find.text('Commencer · 15 min'));
      await tester.pumpAndSettle();
      expect(controller.isRunning, isTrue);
      expect(controller.selectedExercise!.id, 'coherence');
      expect(controller.selectedDurationMinutes, 15);
      expect(controller.remainingSeconds, 900);
      expect(tester.takeException(), isNull);
      await controller.stopSession();
    },
  );

  testWidgets('fermer l’aperçu ne démarre pas de séance', (tester) async {
    final controller = MeditationController();
    addTearDown(controller.dispose);
    await pumpLibrary(tester, controller, textScale: 1.5);
    await tester.tap(find.byKey(const Key('meditation-featured')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip("Fermer l'aperçu"));
    await tester.pumpAndSettle();
    expect(controller.isSetup, isTrue);
    expect(controller.selectedExercise, isNull);
    expect(tester.takeException(), isNull);
  });
}
