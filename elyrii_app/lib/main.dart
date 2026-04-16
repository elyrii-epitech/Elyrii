import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/journal/presentation/providers/journal_provider.dart';
import 'features/chatbot/presentation/providers/chatbot_provider.dart';
import 'features/gamification/presentation/providers/gamification_provider.dart';
import 'features/settings/providers/settings_provider.dart';
>>>>>>> dev
import 'routes/app_routes.dart';
import 'routes/route_generator.dart';
=======
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/config/app_constants.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/services/secure_storage_service.dart';
import 'core/services/theme_provider.dart';
import 'core/services/glass_performance_service.dart';
import 'core/widgets/error_boundary.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/journal/presentation/providers/journal_provider.dart';
import 'features/chatbot/presentation/providers/chatbot_provider.dart';
import 'features/gamification/presentation/providers/gamification_provider.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/dashboard/presentation/providers/dashboard_provider.dart';
import 'routes/app_routes.dart';
import 'routes/route_generator.dart';
=======
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/journal/presentation/providers/journal_provider.dart';
import 'features/chatbot/presentation/providers/chatbot_provider.dart';
import 'features/gamification/presentation/providers/gamification_provider.dart';
import 'features/settings/providers/settings_provider.dart';
>>>>>>> dev
import 'routes/app_routes.dart';
import 'routes/route_generator.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Configure API base URL for current platform
  AppConfig.initialize();

  // Initialize core services
  final secureStorage = SecureStorageService();
  final apiClient = ApiClient(storage: secureStorage);
  final themeProvider = ThemeProvider();
  final performanceService = GlassPerformanceService();

  await Future.wait([themeProvider.init(), performanceService.init()]);

  // Create providers that depend on ApiClient
  final authProvider = AuthProvider(client: apiClient, storage: secureStorage);
  final journalProvider = JournalProvider(client: apiClient);
  final chatbotProvider = ChatbotProvider(storage: secureStorage);
  final gamificationProvider = GamificationProvider(client: apiClient);
  final userProvider = UserProvider(client: apiClient);
  final dashboardProvider = DashboardProvider(apiClient: apiClient);

  // Perform backend health check
  unawaited(apiClient.checkHealth());

  // Check if user is already authenticated
  await authProvider.checkAuthStatus();

  // Configuration de la barre de statut
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Verrouiller l'orientation en portrait
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: performanceService),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: journalProvider),
        ChangeNotifierProvider.value(value: chatbotProvider),
        ChangeNotifierProvider.value(value: gamificationProvider),
        ChangeNotifierProvider.value(value: userProvider),
        ChangeNotifierProvider.value(value: dashboardProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,

          // Thèmes
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,

          builder: (context, child) {
            return GlobalErrorBoundary(child: child!);
          },

<<<<<<< HEAD
          initialRoute:
              authProvider.isAuthenticated ? AppRoutes.home : AppRoutes.login,
>>>>>>> dev
=======
          initialRoute: authProvider.isAuthenticated ? AppRoutes.home : AppRoutes.login,
=======
          initialRoute:
              authProvider.isAuthenticated ? AppRoutes.home : AppRoutes.login,
>>>>>>> dev
          onGenerateRoute: RouteGenerator.generateRoute,
        );
      },
    );
  }
}

/// @deprecated Use ThemeProvider instead via Provider.of[ThemeProvider](context)
/// Kept for backward compatibility during migration
class ThemeSwitcher extends InheritedWidget {
  final VoidCallback toggleTheme;
  final ThemeMode themeMode;

  const ThemeSwitcher({
    super.key,
    required this.toggleTheme,
    required this.themeMode,
    required super.child,
  });

  static ThemeSwitcher? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeSwitcher>();
  }

  @override
  bool updateShouldNotify(ThemeSwitcher oldWidget) {
    return themeMode != oldWidget.themeMode;
  }
}
