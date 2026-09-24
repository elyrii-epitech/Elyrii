import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/widgets/mascot_contact_shadow.dart';
import 'package:elyrii_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:elyrii_app/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:elyrii_app/features/mascot/presentation/pages/mascot_customization_page.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Régression atelier mascotte : aperçu flottant épuré, Esprits 3D natifs
/// et garde-robe multi-catégories (Habillage, Tête, Visage).
Future<MascotProvider> _pumpPage(
  WidgetTester tester, {
  bool demo = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  final storage = SecureStorageService();
  final client = ApiClient(storage: storage);
  final authProvider = AuthProvider(client: client, storage: storage);
  if (demo) {
    await authProvider.startDemoSession();
  }
  final mascotProvider = MascotProvider();

  // Surface haute : toute la page est visible sans scroll.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<MascotProvider>.value(value: mascotProvider),
        ChangeNotifierProvider(
          create: (_) => GamificationProvider(
            client: client,
            isDemoSession: () => authProvider.isDemoSession,
          ),
        ),
      ],
      child: const MaterialApp(home: MascotCustomizationPage()),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return mascotProvider;
}

void main() {
  group('MascotCustomizationPage', () {
    testWidgets('aperçu épuré sans CTA parasite et sections complètes', (
      tester,
    ) async {
      await _pumpPage(tester);

      expect(find.byType(ActionChip), findsNothing);
      expect(find.byType(MascotContactShadow), findsNothing);
      expect(find.text('Un moment avec Elyrii'), findsNothing);

      // Sections Esprits et Garde-robe
      expect(find.text('Esprits d\'Elyrii'), findsOneWidget);
      expect(find.text('Garde-robe & Tenues'), findsOneWidget);

      // Dans la catégorie Habillage (active par défaut), l'écharpe offerte est présente
      expect(find.text('Écharpe Moelleuse Cocon'), findsOneWidget);
    });

    testWidgets('sélectionner un esprit met à jour le modèle et le variant', (
      tester,
    ) async {
      final mascotProvider = await _pumpPage(tester);
      final defaultThemeId = mascotProvider.mascot.themeId;

      await tester.tap(find.text('Automne Cuivré'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(mascotProvider.mascot.themeId, isNot(defaultThemeId));
      expect(mascotProvider.mascot.themeId, 'halloween');
      expect(mascotProvider.currentTheme.variantName, 'Automne');
    });

    testWidgets(
      'navigation par pilules de catégories (Habillage, Tête, Visage)',
      (tester) async {
        await _pumpPage(tester);

        // Les 3 pilules de catégories sont visibles
        expect(find.text('Habillage'), findsOneWidget);
        expect(find.text('Tête'), findsOneWidget);
        expect(find.text('Visage'), findsOneWidget);

        // Habillage actif par défaut
        expect(find.text('Écharpe Moelleuse Cocon'), findsOneWidget);
        expect(find.text('Chapeau de diplômé'), findsNothing);

        // Bascule vers la catégorie Tête
        await tester.tap(find.text('Tête'));
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Chapeau de diplômé'), findsOneWidget);
        expect(find.text('Couronne de Laurier Zen'), findsOneWidget);
        expect(find.text('Casque Audio Gamer Pro'), findsOneWidget);
        expect(find.text('Écharpe Moelleuse Cocon'), findsNothing);

        // Bascule vers la catégorie Visage
        await tester.tap(find.text('Visage'));
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Lunettes Noires Ray-Ban'), findsOneWidget);
        expect(find.text('Étoile Céleste Scintillante'), findsOneWidget);
      },
    );

    testWidgets(
      'équipement d\'un accessoire offert et persistance multi-catégories',
      (tester) async {
        final mascotProvider = await _pumpPage(tester);

        // Équiper l'écharpe (débloquée dès 0 défi)
        await tester.tap(find.text('Écharpe Moelleuse Cocon'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          mascotProvider.mascot.equippedCosmetics.contains('scarf_cozy'),
          isTrue,
        );

        // Aller dans la catégorie Tête et équiper via provider pour simuler
        // un cosmétique débloqué
        mascotProvider.equipCosmetic('custom1', category: 'Tête');
        await tester.pump(const Duration(milliseconds: 200));

        // Les deux accessoires de catégories distinctes cohabitent !
        expect(
          mascotProvider.mascot.equippedCosmetics,
          containsAll(['scarf_cozy', 'custom1']),
        );

        // Équiper un autre vêtement de la catégorie Habillage remplace l'écharpe
        mascotProvider.equipCosmetic('bowtie_chic', category: 'Habillage');
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          mascotProvider.mascot.equippedCosmetics.contains('bowtie_chic'),
          isTrue,
        );
        expect(
          mascotProvider.mascot.equippedCosmetics.contains('scarf_cozy'),
          isFalse,
        );
        expect(
          mascotProvider.mascot.equippedCosmetics.contains('custom1'),
          isTrue,
        );
      },
    );

    testWidgets(
      'Mode Dev débloque toute la garde-robe y compris le palier le plus haut',
      (tester) async {
        final mascotProvider = await _pumpPage(tester, demo: true);

        await tester.tap(find.text('Tête'));
        await tester.pump(const Duration(milliseconds: 200));

        await tester.tap(find.text('Casque Audio Gamer Pro'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          mascotProvider.mascot.equippedCosmetics.contains('headphones_zen'),
          isTrue,
        );
        expect(find.text('Encore un petit effort…'), findsNothing);
      },
    );
  });
}
