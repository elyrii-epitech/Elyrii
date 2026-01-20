import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:elyrii_app/main.dart';
import 'package:elyrii_app/core/services/theme_provider.dart';
import 'package:elyrii_app/core/services/glass_performance_service.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Initialize services
    final themeProvider = ThemeProvider();
    final performanceService = GlassPerformanceService();

    // Pump the app with required providers
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ChangeNotifierProvider<GlassPerformanceService>.value(
              value: performanceService),
        ],
        child: const MyApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify that the app builds and shows the MaterialApp
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
