import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/widgets/mascot_contact_shadow.dart';
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
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

void main() {
  group('MascotCustomizationPage', () {
    testWidgets('aperçu sans CTA d\'animation ni ombre de contact', (
      tester,
    ) async {
      await _pumpPage(tester);

      expect(find.byType(ActionChip), findsNothing);
      expect(find.byType(MascotContactShadow), findsNothing);
      expect(find.text('Un moment avec Elyrii'), findsNothing);
      // L'atelier conserve les thèmes et les douze pièces 3D créées.
      expect(find.text('Thèmes'), findsOneWidget);
      expect(find.text('Accessoires'), findsOneWidget);
      expect(find.text('Chapeau de diplômé'), findsNothing);
      for (final accessory in MascotAccessories.all) {
        expect(find.text(accessory.name), findsOneWidget);
        expect(find.text(accessory.description), findsOneWidget);
      }
      expect(find.text('0 / 12 accessoires débloqués'), findsOneWidget);
    });

    testWidgets('sélectionner un thème met à jour la mascotte', (tester) async {
      final mascotProvider = await _pumpPage(tester);
      final defaultThemeId = mascotProvider.mascot.themeId;

      await tester.tap(find.text('Halloween'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(mascotProvider.mascot.themeId, isNot(defaultThemeId));
      expect(mascotProvider.mascot.themeId, 'halloween');
    });

    testWidgets(
      'les filtres accessibles affichent toutes les familles et reviennent à Tous',
      (tester) async {
        await _pumpPage(tester);
        expect(find.byType(ChoiceChip), findsNWidgets(5));
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Tous'))
              .selected,
          isTrue,
        );
        await tester.scrollUntilVisible(find.text('Cou'), 200);
        await tester.tap(find.text('Cou'));
        await tester.pump();
        expect(find.text('Écharpe cocon'), findsOneWidget);
        expect(find.text('Lunettes rondes'), findsNothing);
        expect(find.text('Béret sauge'), findsNothing);
        await tester.tap(find.text('Tous'));
        await tester.pump();
        expect(find.text('Lunettes rondes'), findsOneWidget);
        expect(find.text('Béret sauge'), findsOneWidget);
      },
    );

    testWidgets(
      'une pièce débloquée remplace la précédente et peut être retirée',
      (tester) async {
        final provider = await _pumpPage(tester, completedCount: 3);
        await tester.ensureVisible(find.text('Béret sauge'));
        await tester.tap(find.text('Béret sauge'));
        await tester.pump();
        expect(provider.mascot.equippedCosmetics, ['beret']);

        await tester.ensureVisible(find.text('Bonnet douillet'));
        await tester.tap(find.text('Bonnet douillet'));
        await tester.pump();
        expect(provider.mascot.equippedCosmetics, ['beanie']);

        // Le titre de l'aperçu reprend aussi la pièce portée.
        await tester.tap(find.text('Bonnet douillet').last);
        await tester.pump();
        expect(provider.mascot.equippedCosmetics, isEmpty);
      },
    );

    testWidgets('un verrou explique le défi restant sans équiper la pièce', (
      tester,
    ) async {
      final provider = await _pumpPage(tester, completedCount: 2);
      await tester.ensureVisible(find.text('Bonnet douillet'));
      await tester.tap(find.text('Bonnet douillet'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(provider.mascot.equippedCosmetics, isEmpty);
      expect(
        find.text(
          'Encore 1 défi à terminer pour débloquer « Bonnet douillet ». Ce palier se débloque après 3 défis terminés.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'une pièce restaurée reste retirable avant le chargement des progrès',
      (tester) async {
        final provider = await _pumpPage(tester, savedCosmetics: ['beret']);
        expect(find.text('Équipé'), findsOneWidget);
        expect(find.text('1 / 12 accessoire débloqué'), findsOneWidget);
        await tester.ensureVisible(find.text('Béret sauge').last);
        await tester.tap(find.text('Béret sauge').last);
        await tester.pump();
        expect(provider.mascot.equippedCosmetics, isEmpty);
        expect(find.text('0 / 12 accessoires débloqués'), findsOneWidget);

        await Scrollable.ensureVisible(
          tester.element(find.text('Béret sauge')),
          alignment: 0.5,
        );
        await tester.pump();
        await tester.tap(find.text('Béret sauge'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(provider.mascot.equippedCosmetics, isEmpty);
        expect(find.text('Encore un petit effort…'), findsOneWidget);
      },
    );

    testWidgets('plusieurs nouveaux paliers donnent une célébration groupée', (
      tester,
    ) async {
      final provider = await _pumpPage(
        tester,
        completedCount: 5,
        seenUnlocks: false,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(UnlockCelebrationDialog), findsOneWidget);
      final dialog = tester.widget<UnlockCelebrationDialog>(
        find.byType(UnlockCelebrationDialog),
      );
      expect(dialog.unlockedCount, 3);
      expect(dialog.accessory.id, 'flower_crown');
      await tester.tap(find.text('L\'équiper maintenant'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(provider.mascot.equippedCosmetics, ['flower_crown']);
      expect(find.byType(UnlockCelebrationDialog), findsNothing);
    });

    testWidgets(
      'la garde-robe et la célébration tiennent sur un écran étroit avec texte agrandi',
      (tester) async {
        await _pumpPage(
          tester,
          completedCount: 5,
          seenUnlocks: false,
          surfaceSize: const Size(320, 700),
          textScale: 1.4,
        );
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Plus tard'));
        await tester.tap(find.text('Plus tard'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.scrollUntilVisible(find.text('Cou').hitTestable(), 200);
        await tester.pump();
        await tester.tap(find.text('Cou'));
        await tester.pump();
        expect(find.text('Écharpe cocon'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
