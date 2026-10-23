import 'package:elyrii_app/app/app_dependencies.dart';
import 'package:elyrii_app/core/widgets/mascot_with_accessories.dart';
import 'package:elyrii_app/core/widgets/mascot_3d_viewer.dart';
import 'package:elyrii_app/core/widgets/pushed_page.dart';
import 'package:elyrii_app/features/dashboard/data/accueil_activities.dart';
import 'package:elyrii_app/features/dashboard/domain/civil_day.dart';
import 'package:elyrii_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:elyrii_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/accessibility_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    final fonts = FontLoader('Poppins')
      ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-Bold.ttf'));
    await fonts.load();
  });

  Future<AppDependencies> mount(
    WidgetTester tester, {
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = (await tester.runAsync(fixture))!;
    await tester.pumpWidget(
      host(app, const DashboardPage(), GlobalKey(), true, textScale),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      visualJournals.remove(app)?.dispose();
      app.dispose();
    });
    return app;
  }

  Future<void> tap(WidgetTester tester, String label) async {
    final target = find.bySemanticsLabel(label).first;
    await tester.ensureVisible(target);
    await tester.runAsync(() => tester.tap(target));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> flush(WidgetTester tester, AppDependencies app) async {
    await tester.runAsync(() async {
      await app.accueilActivities.flushed;
      await app.mascot.flushed;
    });
    await tester.pump();
  }

  for (final textScale in [1.0, 2.2]) {
    testWidgets(
      'la date reste centrée et les commandes s’alignent avec les autres pages à $textScale',
      (tester) async {
        final app = await mount(tester, textScale: textScale);
        final date = tester.getRect(
          find.bySemanticsLabel('Ouvrir le calendrier'),
        );
        final profile = tester.getRect(find.bySemanticsLabel('Profil'));
        expect(date.center.dx, closeTo(195, .01));
        expect(date.left, greaterThan(profile.right));
        expect(find.bySemanticsLabel('Réglages'), findsNothing);
        await tester.pumpWidget(
          host(
            app,
            const PushedPage(title: 'Mon bilan', children: []),
            GlobalKey(),
            true,
            textScale,
          ),
        );
        await tester.pump();
        final back = tester.getRect(find.byTooltip('Retour'));
        expect(profile.center.dy, closeTo(back.center.dy, .01));
        expect(date.center.dy, closeTo(back.center.dy, .01));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'le choix d’humeur change la réponse et reste enregistré après relecture',
    (tester) async {
      final app = await mount(tester);
      await tap(tester, 'Vulnérable');
      await flush(tester, app);
      expect(find.bySemanticsLabel('Écrire 3 lignes'), findsOneWidget);
      expect(
        app.accueilActivities.snapshot.moodDays[CivilDay.fromLocal(
          DateTime.now(),
        )],
        MoodType.sad,
      );
      app.accueilActivities.onUserChanged(isDemo: true);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      expect(
        app.accueilActivities.snapshot.moodDays[CivilDay.fromLocal(
          DateTime.now(),
        )],
        MoodType.sad,
      );
    },
  );

  testWidgets(
    'une humeur éprouvée montre le 3114 et le repos sans rituels ni social',
    (tester) async {
      final app = await mount(tester);
      await tap(tester, 'Éprouvé');
      await flush(tester, app);
      expect(find.textContaining('3114'), findsWidgets);
      expect(find.text('Les rituels peuvent attendre'), findsOneWidget);
      expect(find.text('Rituels du jour'), findsNothing);
      expect(find.text('Un pas vers les autres'), findsNothing);
    },
  );

  testWidgets('un rituel coché reste fait quand la page est remontée', (
    tester,
  ) async {
    final app = await mount(tester);
    await tap(tester, 'Rayonnant');
    await flush(tester, app);
    await tap(tester, 'Cocher Respirer 2 minutes');
    await flush(tester, app);
    expect(find.text('1 sur 3'), findsOneWidget);
    await tester.pumpWidget(host(app, const SizedBox(), GlobalKey(), true, 1));
    await tester.pumpWidget(
      host(app, const DashboardPage(), GlobalKey(), true, 1),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.bySemanticsLabel('Décocher Respirer 2 minutes'),
      findsOneWidget,
    );
    expect(
      app
          .accueilActivities
          .snapshot
          .rituals[CivilDay.fromLocal(DateTime.now())]!
          .isDone(AccueilRitual.breathe),
      isTrue,
    );
  });

  testWidgets(
    'la capsule ouvre Série, Fleurs et Tenue et la date ouvre le calendrier',
    (tester) async {
      await mount(tester);
      for (final (label, title) in [
        ('Ouvrir la série', 'Série'),
        ('Ouvrir les fleurs', 'Fleurs de la semaine'),
        ('Ouvrir la tenue', 'Tenue d’Elyrii'),
      ]) {
        await tap(tester, label);
        expect(find.text(title), findsOneWidget);
        await tester.tap(find.byTooltip('Fermer').last);
        await tester.pump(const Duration(seconds: 1));
      }
      await tap(tester, 'Ouvrir le calendrier');
      expect(find.text('Jours présents'), findsOneWidget);
      await tester.tap(find.byTooltip('Mois précédent'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Jours présents'), findsOneWidget);
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pump();
    },
  );

  testWidgets(
    'annuler rend le look précédent et enregistrer engage tenue et décor',
    (tester) async {
      final app = await mount(tester);
      final original = app.mascot.mascot;
      await tap(tester, 'Ouvrir la tenue');
      final viewer = tester.state(find.byType(Mascot3DViewer).first);
      await tap(tester, 'Astral');
      expect(app.mascot.mascot, original);
      expect(
        tester
            .widget<MascotWithAccessories>(
              find.byType(MascotWithAccessories).first,
            )
            .mascot!
            .themeId,
        'cosmic',
      );
      await tester.runAsync(() => tester.tap(find.byTooltip('Fermer')));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(app.mascot.mascot, original);
      expect(
        tester
            .widget<MascotWithAccessories>(
              find.byType(MascotWithAccessories).first,
            )
            .mascot,
        original,
      );
      await tap(tester, 'Ouvrir la tenue');
      await tap(tester, 'Astral');
      await tap(tester, 'Décor');
      await tap(tester, 'Collines');
      await tester.runAsync(
        () => tester.tap(find.byKey(const ValueKey('save_mascot_look'))),
      );
      await flush(tester, app);
      await tester.pump(const Duration(seconds: 1));
      expect(app.mascot.mascot.themeId, 'cosmic');
      expect(app.accueilActivities.snapshot.decor, MascotDecor.hills);
      expect(find.text('Tenue d’Elyrii'), findsNothing);
      expect(viewer.mounted, isTrue);
    },
  );

  testWidgets(
    'le mouvement réduit présente les états finaux sans entrée en cours',
    (tester) async {
      await mount(tester);
      expect(
        find.text('Comment te sens-tu ce matin ?').evaluate().isNotEmpty ||
            find
                .text('Comment te sens-tu cet après-midi ?')
                .evaluate()
                .isNotEmpty ||
            find.text('Comment te sens-tu ce soir ?').evaluate().isNotEmpty,
        isTrue,
      );
      expect(tester.hasRunningAnimations, isFalse);
      await tap(tester, 'Ouvrir la série');
      expect(find.text('7 jours'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pump();
    },
  );
}
