import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:elyrii_app/main.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/services/theme_provider.dart';
import 'package:elyrii_app/core/services/glass_performance_service.dart';
import 'package:elyrii_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:elyrii_app/features/journal/presentation/providers/journal_provider.dart';
import 'package:elyrii_app/features/chatbot/presentation/providers/chatbot_provider.dart';
import 'package:elyrii_app/features/gamification/presentation/providers/gamification_provider.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Mock secure storage for test environment
    FlutterSecureStorage.setMockInitialValues({});

    // Initialize services
    final secureStorage = SecureStorageService();
    final apiClient = ApiClient(storage: secureStorage);
    final themeProvider = ThemeProvider();
    final performanceService = GlassPerformanceService();

    // Pump the app with all required providers
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ChangeNotifierProvider<GlassPerformanceService>.value(
              value: performanceService),
          ChangeNotifierProvider<AuthProvider>.value(
              value: AuthProvider(client: apiClient, storage: secureStorage)),
          ChangeNotifierProvider<JournalProvider>.value(
              value: JournalProvider(client: apiClient)),
          ChangeNotifierProvider<ChatbotProvider>.value(
              value: ChatbotProvider(storage: secureStorage)),
          ChangeNotifierProvider<GamificationProvider>.value(
              value: GamificationProvider(client: apiClient)),
        ],
        child: const MyApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify that the app builds and shows the MaterialApp
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
