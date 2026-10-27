import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/features/dashboard/presentation/mood_presentation.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';
import 'package:elyrii_app/features/meditation/domain/models/breath_phase.dart';
import 'package:elyrii_app/features/meditation/domain/models/meditation_exercises.dart';
import 'package:elyrii_app/features/meditation/presentation/controllers/meditation_controller.dart';
import 'package:elyrii_app/features/meditation/presentation/pages/meditation_session_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> openSession(
  WidgetTester tester,
  MeditationController controller,
) async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Catalogue')),
      ),
      GoRoute(
        path: '/session',
        builder: (_, _) => MeditationSessionPage(controller: controller),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => MascotProvider(),
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.darkTheme,
      ),
    ),
  );
  await controller.startSession();
  router.push('/session');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('guidage écrit conservé, pause, bilan réel et retour', (
    tester,
  ) async {
    final controller = MeditationController()
      ..setExercise(
        MeditationExercises.all.firstWhere((e) => e.id == 'body-scan'),
      )
      ..setDuration(1);
    addTearDown(controller.dispose);
    await openSession(tester, controller);
    expect(find.text('Scan corporel'), findsOneWidget);
    expect(find.text('S’installer'), findsOneWidget);
    expect(
      find.byKey(const Key('meditation-guidance-instruction')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Mettre en pause'));
    await tester.pump();
    final remaining = controller.remainingSeconds;
    await tester.pump(const Duration(seconds: 2));
    expect(controller.remainingSeconds, remaining);
    expect(find.text('En pause'), findsOneWidget);
    await tester.tap(find.byTooltip('Reprendre'));
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      controller.tick();
    }
    await tester.tap(find.text('Terminer la séance'));
    await tester.pumpAndSettle();
    expect(find.text('12 s'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Bien'));
    await tester.pump();
    expect(controller.selectedMoodIndex, MoodType.happy.index);
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();
    expect(find.text('Catalogue'), findsOneWidget);
    expect(controller.isSetup, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'la quatrième phase est Pause et la séance accepte deux minutes',
    (tester) async {
      final controller = MeditationController()
        ..setBreathingType(BreathingType.carree)
        ..setDuration(2);
      addTearDown(controller.dispose);
      await openSession(tester, controller);
      expect(find.text('2:00 restantes · cycle 1 sur 7'), findsOneWidget);
      for (var i = 0; i < 12; i++) {
        controller.tick();
      }
      await tester.pump();
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('4 s'), findsOneWidget);
      await tester.tap(find.byTooltip('Fermer la séance'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Quitter la séance ?'), findsOneWidget);
      expect(controller.isPaused, isTrue);
      await tester.tap(find.text('Reprendre la séance'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.isRunning, isTrue);
      await tester.tap(find.byTooltip('Fermer la séance'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Interrompre'));
      await tester.pumpAndSettle();
      expect(find.text('Catalogue'), findsOneWidget);
      expect(controller.isSetup, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('le 4-7-8 retrouve le souffle libre après quatre cycles', (
    tester,
  ) async {
    final controller = MeditationController()
      ..setBreathingType(BreathingType.relaxation478)
      ..setDuration(2);
    addTearDown(controller.dispose);
    await openSession(tester, controller);
    for (var i = 0; i < 76; i++) {
      controller.tick();
    }
    await tester.pump();
    expect(find.text('Observe'), findsOneWidget);
    expect(find.text('Ton souffle'), findsOneWidget);
    expect(find.textContaining('cycle '), findsNothing);
    await tester.tap(find.text('Terminer la séance'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('4'), findsOneWidget);
    expect(find.text('1 min 16 s'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
