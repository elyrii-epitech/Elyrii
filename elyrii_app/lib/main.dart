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
import 'features/mascot/presentation/providers/mascot_provider.dart';
import 'features/dashboard/presentation/providers/dashboard_provider.dart';
import 'features/coach/presentation/providers/coach_provider.dart';
import 'routes/app_routes.dart';
import 'routes/route_generator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppConfig.initialize();

  final secureStorage = SecureStorageService();
  final apiClient = ApiClient(storage: secureStorage);
  final themeProvider = ThemeProvider();
  final performanceService = GlassPerformanceService();

  await Future.wait([themeProvider.init(), performanceService.init()]);

  final authProvider = AuthProvider(client: apiClient, storage: secureStorage);
  final journalProvider = JournalProvider(client: apiClient);
  final chatbotProvider = ChatbotProvider(storage: secureStorage);
  final gamificationProvider = GamificationProvider(client: apiClient);
  final userProvider = UserProvider(client: apiClient);
  final mascotProvider = MascotProvider(client: apiClient);
  final dashboardProvider = DashboardProvider(apiClient: apiClient);
  final coachProvider = CoachProvider(client: apiClient);

  // Perform backend health check
  unawaited(apiClient.checkHealth());

  await authProvider.checkAuthStatus();
  bool profileSetupDone = true;
  if (authProvider.isAuthenticated) {
    profileSetupDone = await secureStorage.isProfileSetupCompleted();
    await Future.wait([
      userProvider.loadProfile(),
      userProvider.loadSettings(),
      mascotProvider.loadMascot(),
      dashboardProvider.loadDashboardData(),
      coachProvider.loadCoachData(),
    ]);
    final savedTheme = userProvider.settings?.themeModeValue;
    if (savedTheme != null) {
      themeProvider.setThemeMode(savedTheme);
    }
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        Provider<SecureStorageService>.value(value: secureStorage),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: performanceService),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: journalProvider),
        ChangeNotifierProvider.value(value: chatbotProvider),
        ChangeNotifierProvider.value(value: gamificationProvider),
        ChangeNotifierProvider.value(value: userProvider),
        ChangeNotifierProvider.value(value: mascotProvider),
        ChangeNotifierProvider.value(value: dashboardProvider),
        ChangeNotifierProvider.value(value: coachProvider),
      ],
      child: MyApp(profileSetupDone: profileSetupDone),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool profileSetupDone;

  const MyApp({super.key, required this.profileSetupDone});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          builder: (context, child) {
            return GlobalErrorBoundary(child: child!);
          },
          initialRoute: authProvider.isAuthenticated
              ? (profileSetupDone ? AppRoutes.home : AppRoutes.profileSetup)
              : AppRoutes.login,
          onGenerateRoute: RouteGenerator.generateRoute,
        );
      },
    );
  }
}
