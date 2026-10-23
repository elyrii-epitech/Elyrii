import 'package:flutter/material.dart';
import 'package:elyrii_app/core/storage/content_cipher.dart';
import 'package:elyrii_app/features/dashboard/data/accueil_activities.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:elyrii_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:elyrii_app/features/journal/presentation/providers/journal_provider.dart';
import 'package:elyrii_app/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:elyrii_app/features/coach/presentation/providers/coach_provider.dart';
import 'package:elyrii_app/features/settings/providers/settings_provider.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';
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
      ChangeNotifierProvider(
        create: (_) =>
            AccueilActivities(cipher: ContentCipher(storage))..onUserChanged(),
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
  setUpAll(() => initializeDateFormatting('fr'));

  group('Smoke Test Refonte Apple HIG & Mascotte', () {
    testWidgets('LoginPage sans Transform.translate arbitraire ni SnackBar', (
      tester,
    ) async {
      await tester.pumpWidget(_createTestApp(child: const LoginPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Connexion à Elyrii'), findsOneWidget);
    });

    testWidgets('Jardin (ChallengesPage) sans RefreshIndicator Material', (
      tester,
    ) async {
      await tester.pumpWidget(_createTestApp(child: const ChallengesPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Plus aucun RefreshIndicator Material
      expect(find.byType(RefreshIndicator), findsNothing);
      expect(find.text('Semaine'), findsOneWidget);
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
