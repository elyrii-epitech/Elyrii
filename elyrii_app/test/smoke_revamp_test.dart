import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:elyrii_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:elyrii_app/features/journal/presentation/providers/journal_provider.dart';
import 'package:elyrii_app/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:elyrii_app/features/coach/presentation/providers/coach_provider.dart';
import 'package:elyrii_app/core/widgets/glass/liquid_glass_kit.dart';
import 'package:elyrii_app/features/settings/providers/settings_provider.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';
import 'package:elyrii_app/features/dashboard/presentation/widgets/mascot_peek.dart';
import 'package:elyrii_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:elyrii_app/features/journal/presentation/pages/journal_page.dart';
import 'package:elyrii_app/features/gamification/presentation/pages/challenges_page.dart';
import 'package:elyrii_app/features/coach/presentation/pages/coach_page.dart';
import 'package:elyrii_app/features/auth/presentation/pages/login_page.dart';

Widget _createTestApp({required Widget child}) {
  final storage = SecureStorageService();
  final client = ApiClient(storage: storage);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => AuthProvider(client: client, storage: storage),
      ),
      ChangeNotifierProvider(
        create: (_) => DashboardProvider(apiClient: client),
      ),
      ChangeNotifierProvider(create: (_) => JournalProvider(client: client)),
      ChangeNotifierProvider(
        create: (_) => GamificationProvider(client: client),
      ),
      ChangeNotifierProvider(create: (_) => CoachProvider(client: client)),
      ChangeNotifierProvider(create: (_) => UserProvider(client: client)),
      ChangeNotifierProvider(create: (_) => MascotProvider(client: client)),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Smoke Test Refonte Apple HIG & Mascotte', () {
    testWidgets(
      'Dashboard affiche la mascotte épurée sans LinearProgressIndicator',
      (tester) async {
        await tester.pumpWidget(_createTestApp(child: const DashboardPage()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Mascotte présente et épurée (sans ombre de contact)
        expect(find.byType(MascotPeek), findsOneWidget);

        // Aucun LinearProgressIndicator brut Material
        expect(find.byType(LinearProgressIndicator), findsNothing);

        // Aucune SnackBar
        expect(find.byType(SnackBar), findsNothing);

        // Bouton Réglages circulaire dans le bandeau supérieur
        expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
      },
    );

    testWidgets('LoginPage sans Transform.translate arbitraire ni SnackBar', (
      tester,
    ) async {
      await tester.pumpWidget(_createTestApp(child: const LoginPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Connexion à Elyrii'), findsOneWidget);
    });

    testWidgets(
      'JournalPage sans bandeau sombre avec boutons flottants en verre liquide',
      (tester) async {
        await tester.pumpWidget(_createTestApp(child: const JournalPage()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(CustomScrollView), findsWidgets);
        expect(find.byType(LiquidGlassIconButton), findsWidgets);
        expect(find.text('Journal'), findsWidgets);
      },
    );

    testWidgets('Jardin (ChallengesPage) sans RefreshIndicator Material', (
      tester,
    ) async {
      await tester.pumpWidget(_createTestApp(child: const ChallengesPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Plus aucun RefreshIndicator Material
      expect(find.byType(RefreshIndicator), findsNothing);
      expect(find.text('Mes Quêtes'), findsOneWidget);
    });

    testWidgets(
      'CoachPage utilise un CustomScrollView sans LinearProgressIndicator',
      (tester) async {
        await tester.pumpWidget(_createTestApp(child: const CoachPage()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.byType(RefreshIndicator), findsNothing);
      },
    );
  });
}
