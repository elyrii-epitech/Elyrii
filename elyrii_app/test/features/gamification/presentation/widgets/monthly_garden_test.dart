import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/features/dashboard/domain/accueil_content.dart';
import 'package:elyrii_app/features/dashboard/domain/civil_day.dart';
import 'package:elyrii_app/features/gamification/presentation/widgets/monthly_garden.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  Finder arrow(String tooltip) => find.ancestor(
    of: find.byTooltip(tooltip),
    matching: find.byType(IconButton),
  );

  Widget buildGarden({
    required CivilMonth month,
    required CivilDay today,
    required List<WeekFlower> flowers,
    ValueChanged<CivilMonth>? onMonth,
    ValueChanged<WeekFlower>? onFlower,
    bool reduceMotion = false,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: MonthlyGarden(
            month: month,
            today: today,
            flowers: flowers,
            onMonth: onMonth ?? (_) {},
            onFlower: onFlower ?? (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets(
    'empty month shows honest state and soil without fabricated flowers',
    (tester) async {
      final today = CivilDay(2026, 10, 23);
      final month = CivilMonth(2026, 10);

      await tester.pumpWidget(
        buildGarden(month: month, today: today, flowers: const []),
      );

      expect(find.bySemanticsLabel(RegExp(r'^Fleur : ')), findsNothing);
      expect(find.text('Aucun défi terminé ce mois-ci'), findsOneWidget);

      final prevButton = tester.widget<IconButton>(arrow('Mois précédent'));
      expect(prevButton.onPressed, isNotNull);

      final nextButton = tester.widget<IconButton>(arrow('Mois suivant'));
      expect(nextButton.onPressed, isNull);
    },
  );

  testWidgets(
    'month arrows disable future navigation and allow browsing past',
    (tester) async {
      final today = CivilDay(2026, 10, 23);
      final currentMonth = CivilMonth(2026, 10);
      CivilMonth? navigatedMonth;

      await tester.pumpWidget(
        buildGarden(
          month: currentMonth,
          today: today,
          flowers: const [],
          onMonth: (m) => navigatedMonth = m,
        ),
      );

      expect(
        tester.widget<IconButton>(arrow('Mois suivant')).onPressed,
        isNull,
      );
      expect(
        tester.widget<IconButton>(arrow('Mois précédent')).onPressed,
        isNotNull,
      );

      await tester.tap(find.byTooltip('Mois précédent'));
      expect(navigatedMonth, CivilMonth(2026, 9));

      final pastMonth = CivilMonth(2026, 9);
      await tester.pumpWidget(
        buildGarden(
          month: pastMonth,
          today: today,
          flowers: const [],
          onMonth: (m) => navigatedMonth = m,
        ),
      );

      expect(
        tester.widget<IconButton>(arrow('Mois suivant')).onPressed,
        isNotNull,
      );
      expect(
        tester.widget<IconButton>(arrow('Mois précédent')).onPressed,
        isNotNull,
      );

      await tester.tap(find.byTooltip('Mois suivant'));
      expect(navigatedMonth, CivilMonth(2026, 10));
    },
  );

  testWidgets(
    'every flower of a crowded month (>30) is retained and accessible with >=48 tap targets',
    (tester) async {
      final handle = tester.ensureSemantics();
      final today = CivilDay(2026, 10, 23);
      final month = CivilMonth(2026, 10);
      final crowdedFlowers = List.generate(
        35,
        (i) => WeekFlower(
          challengeId: 'challenge_$i',
          title: 'Défi $i',
          day: CivilDay(2026, 10, (i % 20) + 1),
          mood: null,
        ),
      );

      await tester.pumpWidget(
        buildGarden(month: month, today: today, flowers: crowdedFlowers),
      );

      final flowerFinders = find.bySemanticsLabel(RegExp(r'^Fleur : '));
      expect(flowerFinders, findsNWidgets(35));

      for (var i = 0; i < 35; i++) {
        final size = tester.getSize(flowerFinders.at(i));
        expect(size.width, greaterThanOrEqualTo(48.0));
        expect(size.height, greaterThanOrEqualTo(48.0));
      }

      handle.dispose();
    },
  );

  testWidgets(
    'flower selection callback passes the matching WeekFlower record',
    (tester) async {
      final today = CivilDay(2026, 10, 23);
      final month = CivilMonth(2026, 10);
      final flowerA = WeekFlower(
        challengeId: 'c_a',
        title: 'Méditer 5 minutes',
        day: CivilDay(2026, 10, 10),
        mood: null,
      );
      final flowerB = WeekFlower(
        challengeId: 'c_b',
        title: 'Marcher en forêt',
        day: CivilDay(2026, 10, 15),
        mood: null,
      );

      WeekFlower? selectedFlower;
      await tester.pumpWidget(
        buildGarden(
          month: month,
          today: today,
          flowers: [flowerA, flowerB],
          onFlower: (flower) => selectedFlower = flower,
        ),
      );

      final target = find.bySemanticsLabel(
        RegExp(r'^Fleur : Marcher en forêt'),
      );
      expect(target, findsOneWidget);

      await tester.tap(target);
      expect(selectedFlower, isNotNull);
      expect(selectedFlower!.challengeId, 'c_b');
      expect(selectedFlower!.title, 'Marcher en forêt');
      expect(selectedFlower!.day, CivilDay(2026, 10, 15));
    },
  );

  testWidgets(
    'updating month adds new flower while preserving existing positions without duplicates',
    (tester) async {
      final today = CivilDay(2026, 10, 23);
      final month = CivilMonth(2026, 10);

      final flower1 = WeekFlower(
        challengeId: 'c1',
        title: 'Boire de l’eau',
        day: CivilDay(2026, 10, 5),
        mood: null,
      );
      final flower2 = WeekFlower(
        challengeId: 'c2',
        title: 'Respiration guidée',
        day: CivilDay(2026, 10, 12),
        mood: null,
      );

      await tester.pumpWidget(
        buildGarden(month: month, today: today, flowers: [flower1, flower2]),
      );

      final f1CenterBefore = tester.getCenter(
        find.bySemanticsLabel(RegExp(r'^Fleur : Boire de l’eau')),
      );
      final f2CenterBefore = tester.getCenter(
        find.bySemanticsLabel(RegExp(r'^Fleur : Respiration guidée')),
      );

      final flower3 = WeekFlower(
        challengeId: 'c3',
        title: 'Écriture du soir',
        day: CivilDay(2026, 10, 20),
        mood: null,
      );

      await tester.pumpWidget(
        buildGarden(
          month: month,
          today: today,
          flowers: [flower1, flower2, flower3],
        ),
      );

      expect(find.bySemanticsLabel(RegExp(r'^Fleur : ')), findsNWidgets(3));

      final f1CenterAfter = tester.getCenter(
        find.bySemanticsLabel(RegExp(r'^Fleur : Boire de l’eau')),
      );
      final f2CenterAfter = tester.getCenter(
        find.bySemanticsLabel(RegExp(r'^Fleur : Respiration guidée')),
      );

      expect(f1CenterAfter, equals(f1CenterBefore));
      expect(f2CenterAfter, equals(f2CenterBefore));

      final f3Center = tester.getCenter(
        find.bySemanticsLabel(RegExp(r'^Fleur : Écriture du soir')),
      );
      expect(f3Center, isNot(equals(f1CenterAfter)));
      expect(f3Center, isNot(equals(f2CenterAfter)));
    },
  );

  testWidgets('navigating to a past month replaces the current flowers', (
    tester,
  ) async {
    final today = CivilDay(2026, 10, 23);
    final monthCurrent = CivilMonth(2026, 10);
    final monthPast = CivilMonth(2026, 9);

    final flowerCurrent = WeekFlower(
      challengeId: 'now',
      title: 'Défi actuel',
      day: CivilDay(2026, 10, 10),
      mood: null,
    );
    final flowerPast = WeekFlower(
      challengeId: 'past',
      title: 'Défi passé',
      day: CivilDay(2026, 9, 15),
      mood: null,
    );

    await tester.pumpWidget(
      buildGarden(month: monthCurrent, today: today, flowers: [flowerCurrent]),
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^Fleur : Défi actuel')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      buildGarden(month: monthPast, today: today, flowers: [flowerPast]),
    );

    expect(
      find.bySemanticsLabel(RegExp(r'^Fleur : Défi passé')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^Fleur : Défi actuel')),
      findsNothing,
    );
  });
}
