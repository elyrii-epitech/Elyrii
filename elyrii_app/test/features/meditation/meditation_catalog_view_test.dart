import 'package:elyrii_app/core/widgets/glass/liquid_glass_button.dart';
import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/features/meditation/domain/models/breath_phase.dart';
import 'package:elyrii_app/features/meditation/presentation/controllers/meditation_controller.dart';
import 'package:elyrii_app/features/meditation/presentation/widgets/meditation_catalog_view.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';
import 'package:flutter/material.dart';
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
    tester.widget<LiquidGlassButton>(find.byType(LiquidGlassButton));

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

    testWidgets('le texte à 150 % reste entier sur un petit écran', (
      tester,
    ) async {
      await _pumpCatalog(
        tester,
        controller,
        size: const Size(320, 568),
        textScale: 1.5,
      );
      final benefit = find.text(
        'Sélectionne un mode de respiration ci-dessous pour façonner ta séance.',
      );
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

      for (final type in BreathingType.values) {
        controller.setBreathingType(type);
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: type.name);
      }
    });

    testWidgets('aucune intention présélectionnée : CTA désactivé', (
      tester,
    ) async {
      await _pumpCatalog(tester, controller);

      expect(controller.selectedBreathingType, isNull);
      expect(find.text('Choisis ton intention'), findsOneWidget);
      expect(find.text('Choisis une intention'), findsOneWidget);
      expect(_cta(tester).onPressed, isNull);
    });

    testWidgets(
      'un tap sur une intention sélectionne le mode et active le CTA',
      (tester) async {
        await _pumpCatalog(tester, controller);

        await tester.tap(find.text('Focus'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(controller.selectedBreathingType, BreathingType.carree);
        expect(find.text('Choisis ton intention'), findsNothing);
        expect(_cta(tester).label, 'Commencer la séance (5 min)');
        expect(_cta(tester).onPressed, isNotNull);
      },
    );

    testWidgets('un tap sur une durée met à jour la durée affichée', (
      tester,
    ) async {
      await _pumpCatalog(tester, controller);

      await tester.tap(find.text('Focus'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('10 min'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(controller.selectedDurationMinutes, 10);
      expect(_cta(tester).label, 'Commencer la séance (10 min)');
      expect(_cta(tester).onPressed, isNotNull);
    });
  });
}
