import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/core/glass/elyrii_glass_surface.dart';
import 'package:elyrii_app/core/widgets/glass/liquid_glass_button.dart';
import 'package:elyrii_app/features/meditation/presentation/widgets/meditation_duration_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _openSheet(
  WidgetTester tester, {
  required Duration initialDuration,
  required ValueChanged<Duration?> onResult,
  Size size = const Size(390, 844),
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.light
          ? AppTheme.lightTheme
          : AppTheme.darkTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          highContrast: true,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showModalBottomSheet<Duration>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) =>
                    MeditationDurationSheet(initialDuration: initialDuration),
              );
              onResult(result);
            },
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
}

LiquidGlassButton _confirm(WidgetTester tester) =>
    tester.widget<LiquidGlassButton>(
      find.byKey(const Key('meditation-duration-confirm')),
    );

void main() {
  setUpAll(() async {
    final loader = FontLoader('Poppins')
      ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'));
    await loader.load();
  });

  testWidgets('roues natives heures/minutes et aucun raccourci prédéfini', (
    tester,
  ) async {
    Duration? selected;
    await _openSheet(
      tester,
      initialDuration: const Duration(minutes: 7),
      onResult: (result) => selected = result,
    );
    final picker = tester.widget<CupertinoTimerPicker>(
      find.byKey(const Key('meditation-duration-wheel')),
    );
    expect(picker.mode, CupertinoTimerPickerMode.hm);
    expect(picker.minuteInterval, 1);
    expect(picker.initialTimerDuration, const Duration(minutes: 7));
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('heure'), findsOneWidget);
    expect(find.text('minutes'), findsOneWidget);

    picker.onTimerDurationChanged(const Duration(hours: 3, minutes: 1));
    await tester.pump();
    expect(find.text('3 h 1 min'), findsOneWidget);
    await tester.tap(find.byKey(const Key('meditation-duration-confirm')));
    await tester.pumpAndSettle();
    expect(selected, const Duration(hours: 3, minutes: 1));
  });

  testWidgets('faire défiler chaque roue change la durée confirmée', (
    tester,
  ) async {
    Duration? selected;
    await _openSheet(
      tester,
      initialDuration: const Duration(minutes: 7),
      onResult: (result) => selected = result,
    );
    final wheels = find.descendant(
      of: find.byType(CupertinoTimerPicker),
      matching: find.byType(ListWheelScrollView),
    );
    expect(wheels, findsNWidgets(2));
    final hourWheel = tester.widget<ListWheelScrollView>(wheels.at(0));
    final minuteWheel = tester.widget<ListWheelScrollView>(wheels.at(1));
    (hourWheel.controller! as FixedExtentScrollController).jumpToItem(1);
    (minuteWheel.controller! as FixedExtentScrollController).jumpToItem(13);
    await tester.pumpAndSettle();
    expect(find.text('1 h 13 min'), findsOneWidget);
    await tester.tap(find.byKey(const Key('meditation-duration-confirm')));
    await tester.pumpAndSettle();
    expect(selected, const Duration(hours: 1, minutes: 13));
  });

  testWidgets('zéro bloque la confirmation puis une minute la réactive', (
    tester,
  ) async {
    Duration? selected;
    await _openSheet(
      tester,
      initialDuration: const Duration(minutes: 5),
      onResult: (result) => selected = result,
    );
    final picker = tester.widget<CupertinoTimerPicker>(
      find.byKey(const Key('meditation-duration-wheel')),
    );
    picker.onTimerDurationChanged(Duration.zero);
    await tester.pump();
    expect(_confirm(tester).onPressed, isNull);
    expect(find.text('Choisis au moins une minute.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('meditation-duration-confirm')));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(find.byType(MeditationDurationSheet), findsOneWidget);
    picker.onTimerDurationChanged(const Duration(minutes: 1));
    await tester.pump();
    expect(_confirm(tester).onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('meditation-duration-confirm')));
    await tester.pumpAndSettle();
    expect(selected, const Duration(minutes: 1));
  });

  testWidgets('fermer annule les modifications sans renvoyer de durée', (
    tester,
  ) async {
    Duration? selected = const Duration(minutes: 5);
    await _openSheet(
      tester,
      initialDuration: const Duration(minutes: 5),
      onResult: (result) => selected = result,
    );
    tester
        .widget<CupertinoTimerPicker>(find.byType(CupertinoTimerPicker))
        .onTimerDurationChanged(const Duration(hours: 4, minutes: 17));
    await tester.pump();
    await tester.tap(find.byKey(const Key('meditation-duration-close')));
    await tester.pumpAndSettle();
    expect(selected, isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('320 px, texte à 150 %, durée maximale, thème $brightness', (
      tester,
    ) async {
      Duration? selected;
      await _openSheet(
        tester,
        initialDuration: const Duration(hours: 23, minutes: 59),
        onResult: (result) => selected = result,
        size: const Size(320, 568),
        textScale: 1.5,
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('23 h 59 min'), findsOneWidget);
      final glassSheet = tester.widget<ElyriiGlassSurface>(
        find
            .descendant(
              of: find.byType(MeditationDurationSheet),
              matching: find.byType(ElyriiGlassSurface),
            )
            .first,
      );
      expect(glassSheet.glassColor, isNull);
      final sheetMaterial = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(MeditationDurationSheet),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((sheetMaterial.decoration! as BoxDecoration).color!.a, 1);
      await tester.ensureVisible(
        find.byKey(const Key('meditation-duration-confirm')),
      );
      await tester.tap(find.byKey(const Key('meditation-duration-confirm')));
      await tester.pumpAndSettle();
      expect(selected, const Duration(hours: 23, minutes: 59));
      expect(tester.takeException(), isNull);
    });
  }
}
