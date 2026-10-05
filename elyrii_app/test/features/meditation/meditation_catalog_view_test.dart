import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/core/widgets/glass/liquid_glass_button.dart';
import 'package:elyrii_app/features/meditation/domain/models/breath_phase.dart';
import 'package:elyrii_app/features/meditation/domain/models/meditation_exercises.dart';
import 'package:elyrii_app/features/meditation/presentation/controllers/meditation_controller.dart';
import 'package:elyrii_app/features/meditation/presentation/widgets/meditation_catalog_view.dart';
import 'package:elyrii_app/features/meditation/presentation/widgets/meditation_practice_card.dart';
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

/// Regression : les sélections et les changements de contrôleur doivent se
/// refléter dans le catalogue, sans présélection implicite.
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

VoidCallback? _startCallback(WidgetTester tester) {
  return tester
      .widget<LiquidGlassIconButton>(
        find.descendant(
          of: find.byKey(const Key('meditation-start')),
          matching: find.byType(LiquidGlassIconButton),
        ),
      )
      .onPressed;
}

String _startLabel(WidgetTester tester) {
  return tester
      .widget<Semantics>(find.byKey(const Key('meditation-start')))
      .properties
      .label!;
}

Future<void> _openLibrary(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('meditation-browse')));
  await tester.tap(find.byKey(const Key('meditation-browse')));
  await tester.pumpAndSettle();
}

Finder _libraryText(String text) => find.descendant(
  of: find.byKey(const Key('meditation-library')),
  matching: find.text(text),
);

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

    for (final cfg in [
      (320.0, 568.0, 1.0),
      (390.0, 844.0, 1.0),
      (390.0, 844.0, 1.5),
    ]) {
      testWidgets(
        'lancement accessible après défilement, largeur ${cfg.$1}, texte ${cfg.$3}',
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
          final duration = tester.getRect(
            find.byKey(const Key('meditation-custom-duration')),
          );
          expect(find.text('Commencer').hitTestable(), findsOneWidget);
          expect(cta.height, greaterThanOrEqualTo(44));
          expect(duration.height, greaterThanOrEqualTo(44));
          expect(cta.bottom, lessThanOrEqualTo(dock.top));
          if (cfg.$1 == 390 && cfg.$3 == 1) {
            // Le choix d'une pratique reste accessible sans défiler.
            for (final id in ['facile', 'carree']) {
              final exercise = MeditationExercises.all.firstWhere(
                (e) => e.id == id,
              );
              final subtitle = find.text(exercise.subtitle);
              expect(subtitle.hitTestable(), findsOneWidget);
              expect(tester.getRect(subtitle).bottom, lessThan(dock.top));
            }
          }
          controller.setExercise(MeditationExercises.all.last);
          await tester.pump();
          final scrollable = tester.state<ScrollableState>(
            find.descendant(
              of: find.byKey(const Key('meditation-catalog-scroll')),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Scrollable &&
                    widget.axisDirection == AxisDirection.down,
              ),
            ),
          );
          scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
          await tester.pumpAndSettle();
          expect(
            tester.getRect(find.byKey(const Key('meditation-start'))),
            cta,
          );
          expect(find.text('Commencer').hitTestable(), findsOneWidget);
          expect(_startCallback(tester), isNotNull);
          expect(
            tester.getRect(find.text('Parcourir les sensations')).bottom,
            lessThan(dock.top),
          );
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
      final start = find.text('Commencer');
      expect(start.hitTestable(), findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(start);
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
      expect(find.text('Commencer').hitTestable(), findsOneWidget);
      expect(_startCallback(tester), isNull);
      expect(_startLabel(tester), 'Commencer, choisis une pratique');
    });

    testWidgets('changer de contrôleur puis fermer la vue libère les écoutes', (
      tester,
    ) async {
      await _pumpCatalog(tester, controller);
      final replacement = MeditationController();
      addTearDown(replacement.dispose);
      replacement.setExercise(MeditationExercises.all.first);
      replacement.setDuration(13);
      await _pumpCatalog(tester, replacement);
      expect(_startLabel(tester), 'Commencer Découverte, 13 min');

      controller.setExercise(MeditationExercises.all.last);
      controller.setDuration(73);
      await tester.pump();
      expect(_startLabel(tester), 'Commencer Découverte, 13 min');

      replacement.setExercise(
        MeditationExercises.all.firstWhere((e) => e.id == 'body-scan'),
      );
      replacement.setDuration(8);
      await tester.pump();
      expect(_startLabel(tester), 'Commencer Scan corporel, 8 min');

      await tester.pumpWidget(const SizedBox.shrink());
      replacement.setDuration(9);
      controller.setDuration(74);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'un tap sur une intention sélectionne le mode et active le CTA',
      (tester) async {
        await _pumpCatalog(tester, controller);

        await tester.ensureVisible(
          find.byKey(const Key('meditation-practice-carree')),
        );
        await tester.tap(find.byKey(const Key('meditation-practice-carree')));
        await tester.pump(const Duration(milliseconds: 300));

        expect(controller.selectedBreathingType, BreathingType.carree);
        expect(_startLabel(tester), 'Commencer Focus, 5 min');
        expect(_startCallback(tester), isNotNull);
        try {
          await tester.tap(find.text('Commencer'));
          await tester.pump();
          expect(controller.isRunning, isTrue);
          expect(controller.remainingSeconds, 5 * 60);
        } finally {
          controller.stopSession(finished: false);
        }
      },
    );

    testWidgets(
      'quatre pratiques en accueil, catalogue complet dans la feuille',
      (tester) async {
        await _pumpCatalog(tester, controller);
        expect(
          find.descendant(
            of: find.byKey(const Key('meditation-featured')),
            matching: find.byType(MeditationPracticeCard),
          ),
          findsNWidgets(4),
        );
        expect(find.byType(ChoiceChip), findsNothing);
        await _openLibrary(tester);
        final library = find.byKey(const Key('meditation-library'));
        expect(
          find.descendant(
            of: library,
            matching: find.byType(MeditationPracticeCard),
          ),
          findsNWidgets(MeditationExercises.all.length),
        );
        final filters = tester.widgetList<ChoiceChip>(
          find.descendant(of: library, matching: find.byType(ChoiceChip)),
        );
        expect(filters.map((chip) => (chip.label as Text).data), [
          'Tout',
          'Respiration',
          'Présence',
          'Corps',
          'Bienveillance',
        ]);
        expect(
          find.byKey(const Key('meditation-custom-duration')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'une pratique du catalogue remplace une carte sans allonger la page',
      (tester) async {
        await _pumpCatalog(tester, controller, size: const Size(390, 844));
        await _openLibrary(tester);
        await tester.ensureVisible(_libraryText('Équilibre'));
        await tester.tap(_libraryText('Équilibre'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('meditation-library')), findsNothing);
        expect(controller.selectedExercise?.id, 'coherence');
        expect(_startLabel(tester), 'Commencer Équilibre, 5 min');
        expect(_startCallback(tester), isNotNull);
        expect(
          find.byKey(const Key('meditation-practice-coherence')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('meditation-featured')),
            matching: find.byType(MeditationPracticeCard),
          ),
          findsNWidgets(4),
        );
        expect(tester.takeException(), isNull);
      },
    );

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
        expect(_startCallback(tester), isNotNull);
        final startNode = tester.getSemantics(
          find.byKey(const Key('meditation-start')),
        );
        expect(
          startNode.getSemanticsData().label,
          'Commencer ${exercise.title}, 7 min',
        );
        startNode.owner!.performAction(startNode.id, SemanticsAction.tap);
        await tester.pump();
        expect(controller.isRunning, isTrue);
        expect(controller.remainingSeconds, 7 * 60);
        expect(tester.takeException(), isNull);
      } finally {
        controller.stopSession(finished: false);
        semantics.dispose();
      }
    });

    testWidgets('une durée libre se propage au catalogue et au lancement', (
      tester,
    ) async {
      await _pumpCatalog(tester, controller);
      await tester.ensureVisible(
        find.byKey(const Key('meditation-practice-carree')),
      );
      await tester.tap(find.byKey(const Key('meditation-practice-carree')));
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
      expect(_startLabel(tester), 'Commencer Focus, 1 h 13 min');
      expect(_startCallback(tester), isNotNull);
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
      await _openLibrary(tester);
      await tester.ensureVisible(_libraryText('Corps'));
      await tester.tap(_libraryText('Corps'));
      await tester.pump();
      await tester.ensureVisible(_libraryText('Scan corporel'));
      await tester.tap(_libraryText('Scan corporel'));
      await tester.pumpAndSettle();
      expect(controller.selectedExercise?.id, 'body-scan');
      expect(controller.isGuidedPractice, isTrue);
      expect(controller.selectedBreathingType, isNull);
      expect(_startCallback(tester), isNotNull);
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
      await _openLibrary(tester);
      await tester.ensureVisible(_libraryText('Corps'));
      await tester.tap(_libraryText('Corps'));
      await tester.pump();
      expect(controller.selectedExercise, selected);
      expect(controller.selectedDurationMinutes, 1439);
      expect(_startLabel(tester), 'Commencer ${selected!.title}, 23 h 59 min');
      await tester.tap(find.byKey(const Key('meditation-library-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('meditation-library')), findsNothing);
      expect(controller.selectedExercise, selected);
      expect(controller.selectedDurationMinutes, 1439);
      expect(tester.takeException(), isNull);
    });
  });
}
