import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';
import 'package:elyrii_app/features/meditation/domain/models/meditation_exercises.dart';
import 'package:elyrii_app/features/meditation/presentation/controllers/meditation_controller.dart';
import 'package:elyrii_app/features/meditation/presentation/pages/meditation_session_page.dart';

void main() {
  testWidgets('séance guidée, pause, fin et retour au catalogue', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final controller = MeditationController()
      ..setExercise(
        MeditationExercises.all.firstWhere((e) => e.id == 'body-scan'),
      )
      ..setDuration(1);
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
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => MascotProvider(),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await controller.startSession();
    router.push('/session');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Scan corporel'), findsOneWidget);
    expect(
      find.byKey(const Key('meditation-guidance-instruction')),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expect(controller.isPaused, isTrue);
    final remaining = controller.remainingSeconds;
    await tester.pump(const Duration(seconds: 2));
    expect(controller.remainingSeconds, remaining);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    while (!controller.isFinished) {
      controller.tick();
    }
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Étapes'), findsOneWidget);
    await tester.ensureVisible(find.text('Nouvelle séance'));
    await tester.tap(find.text('Nouvelle séance'));
    await tester.pumpAndSettle();
    expect(find.text('Catalogue'), findsOneWidget);
    expect(controller.isSetup, isTrue);
    expect(tester.takeException(), isNull);
  });
}
