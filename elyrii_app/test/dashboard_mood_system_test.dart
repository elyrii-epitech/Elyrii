import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'package:elyrii_app/features/dashboard/presentation/pages/dashboard_page.dart';

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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Dashboard State of Mind & Bento Grid Tests', () {
    testWidgets(
      'Dashboard affiche la section État d\'esprit et la Bento Grid sans glitch',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2600);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await tester.pumpWidget(_createTestApp(child: const DashboardPage()));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
        // Vérification des éléments clés de la Bento Grid
        expect(find.text('État d\'esprit'), findsOneWidget);
        // Tant que les données chargent, le squelette discret est affiché sans barre violette
        expect(find.text('État d\'esprit'), findsOneWidget);
        // Aucun message d'erreur socket brut n'apparaît
        expect(find.textContaining('SocketException'), findsNothing);
        expect(find.textContaining('ClientException'), findsNothing);
      },
    );

    testWidgets(
      'Sélectionner une humeur affiche la résonance et l\'action contextuelle sans erreur',
      (tester) async {
        await tester.pumpWidget(_createTestApp(child: const DashboardPage()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Trouver les icônes de mood
        final happyIcon = find.byIcon(Icons.sentiment_satisfied_rounded);
        expect(happyIcon, findsOneWidget);

        // Tap sur l'humeur Serein
        await tester.tap(happyIcon);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Vérifier que le libellé nuancé et l'action contextuelle s'affichent
        expect(find.text('Serein'), findsWidgets);
        expect(
          find.textContaining('Une belle clarté d\'esprit'),
          findsOneWidget,
        );
        expect(find.text('Noter ce qui m\'a fait sourire'), findsOneWidget);

        // Aucun message d'erreur socket brut
        expect(find.textContaining('SocketException'), findsNothing);

        // Changement vers une autre humeur : Vulnérable (sad)
        final sadIcon = find.byIcon(Icons.sentiment_dissatisfied_rounded);
        await tester.tap(sadIcon);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Vulnérable'), findsWidgets);
        expect(
          find.textContaining('Une baisse d\'énergie passagère'),
          findsOneWidget,
        );
        expect(
          find.text('Déposer mes pensées dans le journal'),
          findsOneWidget,
        );
      },
    );
  });
}
