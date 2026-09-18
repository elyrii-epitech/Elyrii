import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/widgets/mascot_contact_shadow.dart';
import 'package:elyrii_app/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:elyrii_app/features/mascot/presentation/pages/mascot_customization_page.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Régression atelier mascotte : aperçu épuré (zéro CTA d'animation, zéro
/// ombre de contact) et personnalisation fonctionnelle (thème, accessoire).
Future<MascotProvider> _pumpPage(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  final client = ApiClient(storage: SecureStorageService());
  final mascotProvider = MascotProvider();

  // Surface haute : toute la page est visible sans scroll.
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MascotProvider>.value(value: mascotProvider),
        ChangeNotifierProvider(
          create: (_) => GamificationProvider(client: client),
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
    testWidgets('aperçu sans CTA d\'animation ni ombre de contact', (
      tester,
    ) async {
      await _pumpPage(tester);

      expect(find.byType(ActionChip), findsNothing);
      expect(find.byType(MascotContactShadow), findsNothing);
      expect(find.text('Un moment avec Elyrii'), findsNothing);
      // L'atelier reste complet : thèmes + accessoire.
      expect(find.text('Thèmes'), findsOneWidget);
      expect(find.text('Accessoires'), findsOneWidget);
      expect(find.text('Chapeau de diplômé'), findsOneWidget);
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
      'une seule catégorie d\'accessoires : aucune pilule de filtre',
      (tester) async {
        await _pumpPage(tester);

        // Les pilules de catégorie n'apparaissent qu'à partir de deux
        // familles d'accessoires.
        expect(find.text('Tête'), findsNothing);
      },
    );
  });
}
