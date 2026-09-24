import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'core/theme/app_theme.dart';
import 'core/config/app_constants.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/services/secure_storage_service.dart';
import 'core/services/theme_provider.dart';
import 'core/widgets/error_boundary.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/journal/presentation/providers/journal_provider.dart';
import 'features/chatbot/presentation/providers/chatbot_provider.dart';
import 'features/gamification/presentation/providers/gamification_provider.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/mascot/presentation/providers/mascot_provider.dart';
import 'features/dashboard/presentation/providers/dashboard_provider.dart';
import 'features/coach/presentation/providers/coach_provider.dart';
import 'package:go_router/go_router.dart';
import 'app/router/app_router.dart';
import 'app/launch/elyrii_launch.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppConfig.initialize();

  final secureStorage = SecureStorageService();
  final apiClient = ApiClient(storage: secureStorage);
  final themeProvider = ThemeProvider();

  await Future.wait([themeProvider.init(), LiquidGlassWidgets.initialize()]);

  final authProvider = AuthProvider(client: apiClient, storage: secureStorage);
  final journalProvider = JournalProvider(client: apiClient);
  final chatbotProvider = ChatbotProvider(storage: secureStorage);
  final gamificationProvider = GamificationProvider(
    client: apiClient,
    isDemoSession: () => authProvider.isDemoSession,
  );
  final userProvider = UserProvider(client: apiClient);
  final mascotProvider = MascotProvider(client: apiClient);
  final dashboardProvider = DashboardProvider(
    apiClient: apiClient,
    isDemoSession: () => authProvider.isDemoSession,
  );
  final coachProvider = CoachProvider(client: apiClient);

  // Backend health check stays fire-and-forget.
  unawaited(apiClient.checkHealth());

  // Offline-first startup: restore the session from local storage only
  // (token presence + local JWT expiry check). No network call blocks
  // runApp, so a slow or absent network can never white-screen the launch.
  await authProvider.restoreLocalSession();
  final profileSetupDone = authProvider.isAuthenticated
      ? await secureStorage.isProfileSetupCompleted()
      : true;
  // Le routeur GoRouter lit ce notifier pour lever le guard d'onboarding
  // une fois le profil complété (voir ProfileSetupPage._finish).
  final profileSetupDoneListenable = ValueNotifier<bool>(profileSetupDone);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    LiquidGlassWidgets.wrap(
      brightnessResolver: Theme.maybeBrightnessOf,
      adaptiveQuality: true,
      child: MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: apiClient),
          Provider<SecureStorageService>.value(value: secureStorage),
          ListenableProvider<ValueNotifier<bool>>.value(
            value: profileSetupDoneListenable,
          ),
          ChangeNotifierProvider.value(value: themeProvider),
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider.value(value: journalProvider),
          ChangeNotifierProvider.value(value: chatbotProvider),
          ChangeNotifierProvider.value(value: gamificationProvider),
          ChangeNotifierProvider.value(value: userProvider),
          ChangeNotifierProvider.value(value: mascotProvider),
          ChangeNotifierProvider.value(value: dashboardProvider),
          ChangeNotifierProvider.value(value: coachProvider),
        ],
        child: MyApp(
          authProvider: authProvider,
          profileSetupDoneListenable: profileSetupDoneListenable,
        ),
      ),
    ),
  );

  // Post-launch hydration: verify the session and warm the providers without
  // ever blocking the first frame. Pages already self-load in initState,
  // so these calls only pre-warm data and reconcile the saved theme.
  unawaited(() async {
    await authProvider.revalidateSession();
    if (authProvider.isAuthenticated) {
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
  }());
}

class MyApp extends StatefulWidget {
  final AuthProvider authProvider;
  final ValueNotifier<bool> profileSetupDoneListenable;

  const MyApp({
    super.key,
    required this.authProvider,
    required this.profileSetupDoneListenable,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.createRouter(
      authProvider: widget.authProvider,
      profileSetupDone: widget.profileSetupDoneListenable,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          routerConfig: _router,
          builder: (context, child) {
            // Status bar follows the active theme instead of being forced
            // to dark icons (unreadable in dark mode).
            final brightness = Theme.of(context).brightness;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: brightness == Brightness.dark
                    ? Brightness.light
                    : Brightness.dark,
                statusBarBrightness: brightness == Brightness.dark
                    ? Brightness.dark
                    : Brightness.light,
              ),
              child: ElyriiLaunch(child: GlobalErrorBoundary(child: child!)),
            );
          },
        );
      },
    );
  }
}
