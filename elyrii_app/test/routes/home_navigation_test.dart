import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/widgets/mascot_customize_button.dart';
import 'package:elyrii_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:elyrii_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:elyrii_app/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:elyrii_app/features/journal/presentation/providers/journal_provider.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';
import 'package:elyrii_app/routes/home_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('mascot customization button is only available on Home', (
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
            create: (_) =>
                AuthProvider(client: apiClient, storage: secureStorage),
          ),
          ChangeNotifierProvider(
            create: (_) => DashboardProvider(apiClient: apiClient),
          ),
          ChangeNotifierProvider(
            create: (_) => JournalProvider(client: apiClient),
          ),
          ChangeNotifierProvider(
            create: (_) => GamificationProvider(client: apiClient),
          ),
        ],
        child: const MaterialApp(home: HomeNavigation()),
      ),
    );

    await tester.pump();

    expect(find.byType(MascotCustomizeButton), findsOneWidget);

    await tester.tap(find.text('Jardin'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(MascotCustomizeButton), findsNothing);

    await tester.pump(const Duration(milliseconds: 600));
  });
}
