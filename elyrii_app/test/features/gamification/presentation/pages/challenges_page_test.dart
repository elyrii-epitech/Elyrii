import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/gamification/presentation/pages/challenges_page.dart';
import 'package:elyrii_app/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:elyrii_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('jardin shows garden header without mascot customization', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    final secureStorage = SecureStorageService();
    final apiClient = ApiClient(storage: secureStorage);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MascotProvider()),
          ChangeNotifierProvider(
            create: (_) => GamificationProvider(client: apiClient),
          ),
          ChangeNotifierProvider(
            create: (_) => DashboardProvider(apiClient: apiClient),
          ),
        ],
        child: const MaterialApp(home: ChallengesPage()),
      ),
    );

    await tester.pump();
    // Laisser les animations flutter_animate se stabiliser
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Atelier de présence'), findsOneWidget);
    expect(find.text('Ton jardin intérieur'), findsOneWidget);
    // La personnalisation de la mascotte n'est plus sur la page Jardin
    expect(find.text('Personnaliser Elyrii'), findsNothing);
  });
}
