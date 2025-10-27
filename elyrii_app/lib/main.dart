import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'core/config/app_constants.dart';
import 'routes/app_routes.dart';
import 'routes/route_generator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
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
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light 
          ? ThemeMode.dark 
          : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      
      // Thèmes
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      initialRoute: AppRoutes.home,
      onGenerateRoute: RouteGenerator.generateRoute,
      builder: (context, child) {
        // Passer la fonction de toggle via InheritedWidget
        return ThemeSwitcher(
          toggleTheme: _toggleTheme,
          themeMode: _themeMode,
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}

/// InheritedWidget pour partager la fonction de toggle du thème
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
