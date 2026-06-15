import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/gamification/presentation/pages/challenges_page.dart';
import 'package:elyrii_app/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:elyrii_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:elyrii_app/features/mascot/presentation/pages/mascot_customization_page.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';
import 'package:elyrii_app/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('jardin opens mascot customization from premium top entry', (
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
        child: MaterialApp(
          routes: {
            AppRoutes.mascotCustomization: (_) =>
                const MascotCustomizationPage(),
          },
          home: const ChallengesPage(),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Atelier de présence'), findsOneWidget);
    expect(find.text('Personnaliser Elyrii'), findsOneWidget);

    await tester.tap(find.text('Personnaliser Elyrii'));
    await tester.pumpAndSettle();

    expect(
      find.text('Choisis son ambiance visuelle, sans pression'),
      findsOneWidget,
    );
  });
}
