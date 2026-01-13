import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/config/app_constants.dart';
import 'core/services/theme_provider.dart';
import 'core/services/glass_performance_service.dart';
import 'routes/app_routes.dart';
import 'routes/route_generator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  final themeProvider = ThemeProvider();
  final performanceService = GlassPerformanceService();
  
  await Future.wait([
    themeProvider.init(),
    performanceService.init(),
  ]);

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
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,

          // Thèmes
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          initialRoute: AppRoutes.login,
          onGenerateRoute: RouteGenerator.generateRoute,
        );
      },
    );
  }
}

/// @deprecated Use ThemeProvider instead via Provider.of<ThemeProvider>(context)
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
