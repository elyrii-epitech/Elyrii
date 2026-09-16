import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elyrii_app/app/router/app_router.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/widgets/glass_navigation_bar.dart';
import 'package:elyrii_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:elyrii_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:elyrii_app/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:elyrii_app/features/journal/presentation/providers/journal_provider.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';
import 'package:elyrii_app/features/coach/presentation/providers/coach_provider.dart';
import 'package:elyrii_app/features/settings/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'GoRouter shell affiche la barre de navigation sur les écrans connectés',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});

      final secureStorage = SecureStorageService();
      final apiClient = ApiClient(storage: secureStorage);
      final authProvider = AuthProvider(
        client: apiClient,
        storage: secureStorage,
      );
      final profileSetupDone = ValueNotifier<bool>(true);

      final router = AppRouter.createRouter(
        authProvider: authProvider,
        profileSetupDone: profileSetupDone,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider(create: (_) => MascotProvider()),
            ChangeNotifierProvider(
              create: (_) => DashboardProvider(apiClient: apiClient),
            ),
            ChangeNotifierProvider(
              create: (_) => JournalProvider(client: apiClient),
            ),
            ChangeNotifierProvider(
              create: (_) => GamificationProvider(client: apiClient),
            ),
            ChangeNotifierProvider(
              create: (_) => CoachProvider(client: apiClient),
            ),
            ChangeNotifierProvider(
              create: (_) => UserProvider(client: apiClient),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      // Initialement non authentifié -> redirigé vers /login
      await tester.pumpAndSettle();
      expect(find.byType(GlassNavigationBar), findsNothing);
    },
  );
}
