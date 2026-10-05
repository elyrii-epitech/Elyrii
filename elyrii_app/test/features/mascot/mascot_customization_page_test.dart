import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/core/widgets/glass/liquid_glass_button.dart';
import 'package:elyrii_app/core/widgets/mascot_contact_shadow.dart';
import 'package:elyrii_app/core/widgets/mascot_3d_viewer.dart';
import 'package:elyrii_app/features/mascot/presentation/widgets/mascot_studio_preview.dart';
import 'package:elyrii_app/features/gamification/data/models/gamification_models.dart';
import 'package:elyrii_app/features/gamification/data/repositories/gamification_repository.dart';
import 'package:elyrii_app/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:elyrii_app/features/mascot/data/models/mascot_accessory.dart';
import 'package:elyrii_app/features/mascot/presentation/pages/mascot_customization_page.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';
import 'package:elyrii_app/features/mascot/presentation/widgets/unlock_celebration_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Challenges extends GamificationRepository {
  final int completedCount;

  _Challenges(ApiClient client, this.completedCount) : super(client: client);

  @override
  Future<List<ChallengeTemplate>> getAvailableChallenges() async => [];
  @override
  Future<List<UserChallenge>> getActiveChallenges() async => [];
  @override
  Future<List<UserChallenge>> getProposals() async => [];
  @override
  Future<List<UserChallenge>> getCompletedChallenges() async => List.generate(
    completedCount,
    (i) => UserChallenge(
      id: 'completed-$i',
      userId: 'user',
      challengeId: 'challenge-$i',
      status: 'COMPLETED',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  );
}

Future<MascotProvider> _pumpPage(
  WidgetTester tester, {
  int completedCount = 0,
  bool seenUnlocks = true,
  List<String> savedCosmetics = const [],
  Size surfaceSize = const Size(800, 2000),
  double textScale = 1,
  bool dark = false,
  bool highContrast = false,
  bool reducedMotion = false,
}) async {
  SharedPreferences.setMockInitialValues({
    'elyrii_mascot_customization': savedCosmetics,
    if (seenUnlocks)
      'elyrii_seen_cosmetic_unlocks': MascotAccessories.all
          .map((a) => a.id)
          .toList(),
  });
  FlutterSecureStorage.setMockInitialValues({});
  final client = ApiClient(storage: SecureStorageService());
  final mascotProvider = MascotProvider();

  tester.view.physicalSize = surfaceSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MascotProvider>.value(value: mascotProvider),
        ChangeNotifierProvider(
          create: (_) => GamificationProvider(
            repository: _Challenges(client, completedCount),
          ),
        ),
      ],
      child: MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            highContrast: highContrast,
            disableAnimations: reducedMotion,
          ),
          child: child!,
        ),
        home: const MascotCustomizationPage(),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return mascotProvider;
}

MascotStudioPreview _preview(WidgetTester tester) =>
    tester.widget(find.byType(MascotStudioPreview));

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('save_mascot_look')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('Atelier Elyrii', () {
    testWidgets('les filtres équipés gardent leur nom accessible', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await _pumpPage(
          tester,
          completedCount: 12,
          savedCosmetics: ['graduate_cap', 'cheek_sparkle'],
        );
        await tester.tap(find.text('Collection'));
        await tester.pump();
        for (final category in ['Tête', 'Visage']) {
          final chip = find.widgetWithText(ChoiceChip, category);
          expect(tester.getSemantics(chip).label, category);
        }
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('aperçu persistant et paliers réels', (tester) async {
      await _pumpPage(tester, completedCount: 3);
      expect(find.text('Atelier Elyrii'), findsOneWidget);
      expect(find.text('Style'), findsOneWidget);
      expect(find.text('Couleurs'), findsOneWidget);
      expect(find.text('Collection'), findsOneWidget);
      expect(find.byType(MascotContactShadow), findsNothing);
      expect(find.text('4 / 15'), findsOneWidget);
      expect(find.text('Éclat céleste'), findsOneWidget);
      expect(find.text('Encore 1 défi à ton rythme'), findsOneWidget);
      final scene = tester.state(find.byType(Mascot3DViewer));
      await tester.tap(find.text('Collection'));
      await tester.pump();
      await tester.ensureVisible(find.text('Petit sac à dos'));
      expect(find.byType(MascotStudioPreview).hitTestable(), findsOneWidget);
      expect(tester.state(find.byType(Mascot3DViewer)), same(scene));
    });

    testWidgets('un thème est essayé, annulé puis enregistré explicitement', (
      tester,
    ) async {
      final provider = await _pumpPage(tester);
      await tester.tap(find.text('Automne Cuivré'));
      await tester.pump();
      expect(_preview(tester).mascot.themeId, 'halloween');
      expect(provider.mascot.themeId, 'nature');
      await tester.tap(find.byTooltip('Annuler la dernière modification'));
      await tester.pump();
      expect(_preview(tester).mascot.themeId, 'nature');
      await tester.tap(find.text('Astral'));
      await tester.pump();
      await _save(tester);
      expect(provider.mascot.themeId, 'cosmic');
      expect(find.text('Ton look est enregistré'), findsOneWidget);
    });

    testWidgets('couleurs arbitraires indépendantes et saisie invalide', (
      tester,
    ) async {
      final provider = await _pumpPage(tester);
      await tester.tap(find.text('Couleurs'));
      await tester.pump();
      final hex = find.byKey(const ValueKey('mascot_hex_color'));
      await tester.ensureVisible(hex);
      await tester.enterText(hex, '12ab9f');
      await tester.tap(find.byTooltip('Appliquer la couleur'));
      await tester.pump();
      expect(_preview(tester).mascot.appearance.colors['body'], '#12AB9F');
      await tester.ensureVisible(find.text('Yeux'));
      await tester.tap(find.text('Yeux'));
      await tester.pump();
      await tester.ensureVisible(hex);
      await tester.enterText(hex, 'ZZ0000');
      await tester.tap(find.byTooltip('Appliquer la couleur'));
      await tester.pump();
      expect(
        find.text('Saisis 6 caractères, par exemple B8A3DC.'),
        findsOneWidget,
      );
      expect(_preview(tester).mascot.appearance.colors['eyes'], isNull);
      await tester.enterText(hex, '3B3549');
      await tester.tap(find.byTooltip('Appliquer la couleur'));
      await tester.pump();
      await _save(tester);
      expect(provider.mascot.appearance.colors, {
        'body': '#12AB9F',
        'eyes': '#3B3549',
      });
      final restored = MascotProvider();
      await restored.loadMascot();
      expect(restored.mascot.appearance, provider.mascot.appearance);
      restored.dispose();
    });

    testWidgets('un glissement de couleur s’annule en une seule action', (
      tester,
    ) async {
      await _pumpPage(tester);
      await tester.tap(find.text('Couleurs'));
      await tester.pump();
      await tester.drag(find.byType(Slider).first, const Offset(180, 0));
      await tester.pump();
      expect(_preview(tester).mascot.appearance.colors['body'], isNotNull);
      await tester.tap(find.byTooltip('Annuler la dernière modification'));
      await tester.pump();
      expect(_preview(tester).mascot.appearance.colors, isEmpty);
    });

    testWidgets(
      'une tenue combine quatre zones et remplace seulement sa zone',
      (tester) async {
        final provider = await _pumpPage(tester, completedCount: 36);
        await tester.tap(find.text('Collection'));
        await tester.pump();
        for (final name in [
          'Béret sauge',
          'Lunettes rondes',
          'Écharpe cocon',
          'Petit sac à dos',
        ]) {
          await tester.ensureVisible(find.text(name));
          await tester.tap(find.text(name));
          await tester.pump();
        }
        expect(_preview(tester).mascot.equippedCosmetics, [
          'beret',
          'round_glasses',
          'cozy_scarf',
          'mini_backpack',
        ]);
        expect(provider.mascot.equippedCosmetics, isEmpty);
        await tester.ensureVisible(find.text('Bonnet douillet'));
        await tester.tap(find.text('Bonnet douillet'));
        await tester.pump();
        expect(_preview(tester).mascot.equippedCosmetics, [
          'beanie',
          'round_glasses',
          'cozy_scarf',
          'mini_backpack',
        ]);
        await _save(tester);
        expect(provider.mascot.equippedCosmetics, [
          'beanie',
          'round_glasses',
          'cozy_scarf',
          'mini_backpack',
        ]);
      },
    );

    testWidgets(
      'une récompense verrouillée peut être essayée sans être sauvegardée',
      (tester) async {
        final provider = await _pumpPage(tester, completedCount: 2);
        await tester.tap(find.text('Collection'));
        await tester.pump();
        await tester.ensureVisible(find.text('Bonnet douillet').last);
        await tester.tap(find.text('Bonnet douillet').last);
        await tester.pumpAndSettle();
        expect(
          find.text('Encore 1 défi à terminer · 3 défis terminés'),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Essayer sur ma mascotte'));
        await tester.tap(find.text('Essayer sur ma mascotte'));
        await tester.pumpAndSettle();
        expect(_preview(tester).mascot.equippedCosmetics, ['beanie']);
        expect(provider.mascot.equippedCosmetics, isEmpty);
        expect(
          tester
              .widget<LiquidGlassButton>(
                find.byKey(const ValueKey('save_mascot_look')),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.byTooltip('Terminer l’essai'));
        await tester.pump();
        expect(_preview(tester).mascot.equippedCosmetics, isEmpty);
      },
    );

    testWidgets('filtres de famille et de disponibilité', (tester) async {
      await _pumpPage(tester, completedCount: 3);
      await tester.tap(find.text('Collection'));
      await tester.pump();
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Cou'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Cou'));
      await tester.pump();
      expect(find.text('Écharpe cocon'), findsOneWidget);
      expect(find.text('Lunettes rondes'), findsNothing);
      await tester.tap(find.text('Disponibles'));
      await tester.pump();
      expect(find.text('Écharpe cocon'), findsNothing);
      expect(
        find.textContaining('Tes premières pièces t’attendent.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Tous'));
      await tester.pump();
      expect(find.text('Béret sauge'), findsOneWidget);
      expect(find.text('Bonnet douillet'), findsOneWidget);
    });

    testWidgets(
      'une pièce restaurée reste retirable sans progression chargée',
      (tester) async {
        final provider = await _pumpPage(tester, savedCosmetics: ['beret']);
        await tester.tap(find.text('Collection'));
        await tester.pump();
        await tester.ensureVisible(find.text('Béret sauge'));
        await tester.tap(find.text('Béret sauge'));
        await tester.pump();
        await _save(tester);
        expect(provider.mascot.equippedCosmetics, isEmpty);
      },
    );

    testWidgets(
      'les nouveaux paliers se célèbrent ensemble et équipent un brouillon',
      (tester) async {
        final provider = await _pumpPage(
          tester,
          completedCount: 5,
          seenUnlocks: false,
        );
        await tester.pump(const Duration(seconds: 1));
        final dialog = tester.widget<UnlockCelebrationDialog>(
          find.byType(UnlockCelebrationDialog),
        );
        expect(dialog.unlockedCount, 6);
        await tester.tap(find.text('L\'équiper maintenant'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(_preview(tester).mascot.equippedCosmetics, ['flower_crown']);
        expect(provider.mascot.equippedCosmetics, isEmpty);
        await _save(tester);
        expect(provider.mascot.equippedCosmetics, ['flower_crown']);
      },
    );

    for (final dark in [false, true]) {
      testWidgets('récompenses lisibles sans animation, dark=$dark', (
        tester,
      ) async {
        await _pumpPage(
          tester,
          completedCount: 5,
          seenUnlocks: false,
          surfaceSize: const Size(320, 568),
          textScale: 1.5,
          dark: dark,
          reducedMotion: true,
        );
        await tester.pumpAndSettle();
        expect(find.byType(UnlockCelebrationDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Plus tard'));
        await tester.tap(find.text('Plus tard'));
        await tester.pumpAndSettle();
        expect(find.byType(UnlockCelebrationDialog), findsNothing);
      });

      testWidgets(
        'écran compact, texte agrandi et contraste élevé, dark=$dark',
        (tester) async {
          await _pumpPage(
            tester,
            completedCount: 5,
            surfaceSize: const Size(320, 568),
            textScale: 1.5,
            dark: dark,
            highContrast: true,
            reducedMotion: true,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Collection'));
          await tester.pump();
          await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Cou'));
          await tester.tap(find.widgetWithText(ChoiceChip, 'Cou'));
          await tester.pump();
          expect(find.text('Écharpe cocon'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
