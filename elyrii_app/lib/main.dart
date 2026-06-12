import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final mascotProvider = MascotProvider();

  await authProvider.checkAuthStatus();

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
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: performanceService),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: journalProvider),
        ChangeNotifierProvider.value(value: chatbotProvider),
        ChangeNotifierProvider.value(value: gamificationProvider),
        ChangeNotifierProvider.value(value: userProvider),
        ChangeNotifierProvider.value(value: mascotProvider),
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
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          builder: (context, child) {
            return GlobalErrorBoundary(child: child!);
          },
          initialRoute:
              authProvider.isAuthenticated ? AppRoutes.home : AppRoutes.login,
          onGenerateRoute: RouteGenerator.generateRoute,
        );
      },
    );
  }
}
