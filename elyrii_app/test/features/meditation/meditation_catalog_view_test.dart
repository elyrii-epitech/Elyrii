import 'package:elyrii_app/core/widgets/glass/liquid_glass_button.dart';
import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/features/meditation/domain/models/breath_phase.dart';
import 'package:elyrii_app/features/meditation/domain/models/meditation_exercises.dart';
import 'package:elyrii_app/features/meditation/presentation/controllers/meditation_controller.dart';
import 'package:elyrii_app/features/meditation/presentation/widgets/meditation_catalog_view.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:elyrii_app/app/router/app_shell.dart';
import 'package:elyrii_app/core/widgets/glass_navigation_bar.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression : la vue catalogue doit se reconstruire à chaque notification du
/// contrôleur (sélection d'intention et de durée) et ne rien présélectionner.
Future<void> _pumpCatalog(
  WidgetTester tester,
  MeditationController controller, {
  Size size = const Size(800, 1600),
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});

  // Surface haute : tout le catalogue est visible sans scroll.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => MascotProvider())],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(body: MeditationCatalogView(controller: controller)),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

LiquidGlassButton _cta(WidgetTester tester) =>
    tester.widget<LiquidGlassButton>(find.byKey(const Key('meditation-start')));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Poppins')
      ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-Bold.ttf'));
    await loader.load();
  });

  group('MeditationCatalogView', () {
    late MeditationController controller;

    setUp(() {
      controller = MeditationController();
    });

    tearDown(() {
      controller.dispose();
    });

    for (final cfg in [(320.0, 568.0, 1.0), (390.0, 844.0, 1.5)]) {
      testWidgets(
        'lancement dégagé du dock, largeur ${cfg.$1}, texte ${cfg.$3}',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          FlutterSecureStorage.setMockInitialValues({});
          tester.view.physicalSize = Size(cfg.$1, cfg.$2);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final router = GoRouter(
            initialLocation: '/branch3',
            routes: [
              StatefulShellRoute.indexedStack(
                builder: (_, _, shell) => AppShell(navigationShell: shell),
                branches: [
                  for (var i = 0; i < 6; i++)
                    StatefulShellBranch(
                      routes: [
                        GoRoute(
                          path: '/branch$i',
                          builder: (_, _) => i == 3
                              ? Scaffold(
                                  body: MeditationCatalogView(
                                    controller: controller,
                                  ),
                                )
                              : const Scaffold(body: Text('Autre onglet')),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            ChangeNotifierProvider(
              create: (_) => MascotProvider(),
              child: MaterialApp.router(
                routerConfig: router,
                theme: AppTheme.lightTheme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(cfg.$3),
                    padding: const EdgeInsets.only(top: 24, bottom: 20),
                  ),
                  child: child!,
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          final cta = tester.getRect(find.byKey(const Key('meditation-start')));
          final dock = tester.getRect(find.byType(GlassNavigationBar));
          expect(cta.bottom, lessThanOrEqualTo(dock.top));
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('le texte à 150 % reste entier sur un petit écran', (
      tester,
    ) async {
      await _pumpCatalog(
        tester,
        controller,
        size: const Size(320, 568),
        textScale: 1.5,
      );
      final benefit = find.text('Un moment pour toi.');
      final paragraph = tester.renderObject<RenderParagraph>(benefit);
      final painter = TextPainter(
        text: paragraph.text,
        textDirection: paragraph.textDirection,
        textScaler: paragraph.textScaler,
      )..layout(maxWidth: paragraph.size.width);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(paragraph.size.height, greaterThanOrEqualTo(painter.height));
      painter.dispose();
      expect(tester.takeException(), isNull);

      for (final exercise in MeditationExercises.all) {
        controller.setExercise(exercise);
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: exercise.id);
      }
    });

    testWidgets('aucune intention présélectionnée : CTA désactivé', (
      tester,
    ) async {
      await _pumpCatalog(tester, controller);

      expect(controller.selectedBreathingType, isNull);
      expect(controller.selectedExercise, isNull);
      expect(find.text('À ton rythme.'), findsOneWidget);
      expect(find.text('Choisis un exercice'), findsNothing);
      expect(find.text('Commencer'), findsOneWidget);
      expect(_cta(tester).onPressed, isNull);
      expect(_cta(tester).style, LiquidGlassButtonStyle.gray);
    });

    testWidgets(
      'un tap sur une intention sélectionne le mode et active le CTA',
      (tester) async {
        await _pumpCatalog(tester, controller);

        await tester.ensureVisible(find.text('Focus'));
        await tester.tap(find.text('Focus'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(controller.selectedBreathingType, BreathingType.carree);
        expect(_cta(tester).label, 'Commencer · 5 min');
        expect(_cta(tester).style, LiquidGlassButtonStyle.filled);
        expect(_cta(tester).onPressed, isNotNull);
      },
    );

    testWidgets('la page retire les informations et les durées prédéfinies', (
      tester,
    ) async {
      await _pumpCatalog(tester, controller);
      expect(find.byIcon(Icons.info_outline_rounded), findsNothing);
      expect(find.text('Guide et références'), findsNothing);
      expect(find.text('Conseils et références'), findsNothing);
      final filters = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
      expect(filters.map((chip) => (chip.label as Text).data), [
        'Tout',
        'Respiration',
        'Présence',
        'Corps',
        'Bienveillance',
      ]);
      expect(find.text('Durée libre'), findsOneWidget);
    });

    testWidgets('durée et pratique annoncées une fois et activables', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await _pumpCatalog(tester, controller);
        final duration = find.bySemanticsLabel('Durée libre');
        expect(duration, findsOneWidget);
        final durationNode = tester.getSemantics(duration);
        final durationData = durationNode.getSemanticsData();
        expect(durationData.label, 'Durée libre');
        expect(durationData.value, '5 min');
        expect(durationData.hasAction(SemanticsAction.tap), isTrue);

        durationNode.owner!.performAction(durationNode.id, SemanticsAction.tap);
        await tester.pumpAndSettle();
        final wheel = tester.widget<CupertinoTimerPicker>(
          find.byKey(const Key('meditation-duration-wheel')),
        );
        wheel.onTimerDurationChanged(const Duration(minutes: 7));
        await tester.pump();
        await tester.tap(find.byKey(const Key('meditation-duration-confirm')));
        await tester.pumpAndSettle();
        final updatedDuration = tester
            .getSemantics(duration)
            .getSemanticsData();
        expect(updatedDuration.label, 'Durée libre');
        expect(updatedDuration.value, '7 min');

        final exercise = MeditationExercises.all.first;
        final label = '${exercise.title}. ${exercise.subtitle}';
        final card = find.bySemanticsLabel(label);
        expect(card, findsOneWidget);
        final cardNode = tester.getSemantics(card);
        expect(cardNode.getSemanticsData().label, label);
        expect(
          cardNode.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
        );
        cardNode.owner!.performAction(cardNode.id, SemanticsAction.tap);
        await tester.pump(const Duration(milliseconds: 300));
        expect(controller.selectedExercise, exercise);
        expect(tester.getSemantics(card).getSemanticsData().label, label);
        expect(_cta(tester).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('une durée libre se propage au catalogue et au lancement', (
      tester,
    ) async {
      await _pumpCatalog(tester, controller);
      await tester.ensureVisible(find.text('Focus'));
      await tester.tap(find.text('Focus'));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const Key('meditation-custom-duration')),
      );
      await tester.tap(find.byKey(const Key('meditation-custom-duration')));
      await tester.pumpAndSettle();
      final wheel = tester.widget<CupertinoTimerPicker>(
        find.byKey(const Key('meditation-duration-wheel')),
      );
      wheel.onTimerDurationChanged(const Duration(hours: 1, minutes: 13));
      await tester.pump();
      await tester.tap(find.byKey(const Key('meditation-duration-confirm')));
      await tester.pumpAndSettle();

      expect(controller.selectedDurationMinutes, 73);
      expect(controller.remainingSeconds, 4380);
      expect(find.text('1 h 13 min'), findsOneWidget);
      expect(_cta(tester).label, 'Commencer · 1 h 13 min');
      expect(_cta(tester).onPressed, isNotNull);
      expect(controller.selectedExercise?.id, 'carree');
    });

    testWidgets('fermer les roues conserve la durée et la pratique', (
      tester,
    ) async {
      controller.setSessionDuration(const Duration(minutes: 7));
      controller.setExercise(MeditationExercises.all.first);
      final selected = controller.selectedExercise;
      await _pumpCatalog(tester, controller);
      await tester.tap(find.byKey(const Key('meditation-custom-duration')));
      await tester.pumpAndSettle();
      tester
          .widget<CupertinoTimerPicker>(
            find.byKey(const Key('meditation-duration-wheel')),
          )
          .onTimerDurationChanged(const Duration(hours: 4, minutes: 2));
      await tester.pump();
      await tester.tap(find.byKey(const Key('meditation-duration-close')));
      await tester.pumpAndSettle();
      expect(controller.selectedDuration, const Duration(minutes: 7));
      expect(controller.selectedExercise, selected);
      expect(find.text('7 min'), findsOneWidget);
    });

    testWidgets('le filtre Corps propose une vraie pratique guidée', (
      tester,
    ) async {
      await _pumpCatalog(tester, controller);
      await tester.ensureVisible(find.text('Corps'));
      await tester.tap(find.text('Corps'));
      await tester.pump();
      await tester.ensureVisible(find.text('Scan corporel'));
      await tester.tap(find.text('Scan corporel'));
      await tester.pump();
      expect(controller.selectedExercise?.id, 'body-scan');
      expect(controller.isGuidedPractice, isTrue);
      expect(controller.selectedBreathingType, isNull);
      expect(_cta(tester).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('changer de filtre conserve une durée libre et la sélection', (
      tester,
    ) async {
      controller.setSessionDuration(const Duration(hours: 23, minutes: 59));
      controller.setExercise(MeditationExercises.all.first);
      final selected = controller.selectedExercise;
      await _pumpCatalog(
        tester,
        controller,
        size: const Size(320, 568),
        textScale: 1.5,
      );
      await tester.scrollUntilVisible(
        find.text('Corps').hitTestable(),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Corps'));
      await tester.pump();
      expect(controller.selectedExercise, selected);
      expect(controller.selectedDurationMinutes, 1439);
      expect(_cta(tester).label, 'Commencer · 23 h 59 min');
      expect(tester.takeException(), isNull);
    });
  });
}
