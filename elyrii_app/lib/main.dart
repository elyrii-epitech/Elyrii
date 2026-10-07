import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:go_router/go_router.dart';

import 'app/app_dependencies.dart';
import 'app/router/app_router.dart';
import 'app/launch/elyrii_launch.dart';
import 'core/config/app_config.dart';
import 'core/config/app_constants.dart';
import 'core/diagnostics/app_diagnostics.dart';
import 'core/theme/app_theme.dart';
import 'core/network/api_client.dart';
import 'core/services/secure_storage_service.dart';
import 'core/services/theme_provider.dart';
import 'core/widgets/error_boundary.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/journal/presentation/providers/journal_provider.dart';
import 'features/chatbot/presentation/providers/chatbot_provider.dart';
import 'features/coach/presentation/providers/coach_provider.dart';
import 'features/dashboard/presentation/providers/dashboard_provider.dart';
import 'features/gamification/presentation/providers/gamification_provider.dart';
import 'features/mascot/presentation/providers/mascot_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final defaultError = FlutterError.onError;
  FlutterError.onError = (details) {
    AppDiagnostics.record('flutter_error', details.exception);
    defaultError?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppDiagnostics.record('async_error', error);
    return true;
  };
  runApp(const ApplicationBootstrap());
}

Future<AppDependencies> initializeApplication() async {
  AppConfig.initialize();
  await initializeDateFormatting('fr');
  await initializeDateFormatting('en');
  await LiquidGlassWidgets.initialize();
  final storage = SecureStorageService();
  final api = ApiClient(storage: storage);
  final theme = ThemeProvider();
  AppDependencies? dependencies;
  try {
    await theme.init();
    dependencies = AppDependencies(storage: storage, api: api, theme: theme);
    await dependencies.initialize();
    if (kDebugMode && const bool.fromEnvironment('CHECK_BACKEND_HEALTH')) {
      unawaited(
        api.checkHealth().catchError(
          (Object error) => AppDiagnostics.record('health_check', error),
        ),
      );
    }
    unawaited(
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]),
    );
    return dependencies;
  } catch (_) {
    if (dependencies != null) {
      dependencies.dispose();
    } else {
      api.dispose();
      theme.dispose();
    }
    rethrow;
  }
}

/// The first frame exists before plugin or storage initialization. Failures
/// have an explicit retry path; late initialization attempts are disposed.
class ApplicationBootstrap extends StatefulWidget {
  final Future<AppDependencies> Function()? initialize;
  const ApplicationBootstrap({super.key, this.initialize});
  @override
  State<ApplicationBootstrap> createState() => _ApplicationBootstrapState();
}

class _ApplicationBootstrapState extends State<ApplicationBootstrap> {
  AppDependencies? _dependencies;
  bool _failed = false;
  int _attempt = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    final attempt = ++_attempt;
    setState(() => _failed = false);
    final startup = Future<AppDependencies>.sync(
      widget.initialize ?? initializeApplication,
    );
    unawaited(
      startup.then<void>((services) {
        if (!mounted || attempt != _attempt) services.dispose();
      }, onError: (Object _, StackTrace _) {}),
    );
    try {
      final services = await startup.timeout(const Duration(seconds: 30));
      if (!mounted || attempt != _attempt) return;
      setState(() => _dependencies = services);
    } catch (error) {
      AppDiagnostics.record('startup_failed', error);
      if (mounted && attempt == _attempt) {
        _attempt++;
        setState(() => _failed = true);
      }
    }
  }

  @override
  void dispose() {
    _attempt++;
    _dependencies?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = _dependencies;
    if (services == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        // Leave the platform's initial deep link to GoRouter after startup.
        builder: (context, _) => Scaffold(
          body: SafeArea(
            child: Center(
              child: _failed
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Impossible d’ouvrir Elyrii pour le moment.',
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => unawaited(_start()),
                          child: const Text('Réessayer'),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(
                      semanticsLabel: 'Ouverture d’Elyrii',
                    ),
            ),
          ),
        ),
      );
    }
    return LiquidGlassWidgets.wrap(
      brightnessResolver: Theme.maybeBrightnessOf,
      adaptiveQuality: true,
      child: MultiProvider(
        providers: [
          Provider<AppDependencies>.value(value: services),
          Provider<ApiClient>.value(value: services.api),
          Provider<SecureStorageService>.value(value: services.storage),
          ListenableProvider<ValueNotifier<bool>>.value(
            value: services.profileSetupDone,
          ),
          ChangeNotifierProvider<ThemeProvider>.value(value: services.theme),
          ChangeNotifierProvider<AuthProvider>.value(value: services.auth),
          ChangeNotifierProvider<UserProvider>.value(value: services.user),
          ChangeNotifierProvider<JournalProvider>.value(
            value: services.journal,
          ),
          ChangeNotifierProvider<ChatbotProvider>.value(value: services.chat),
          ChangeNotifierProvider<CoachProvider>.value(value: services.coach),
          ChangeNotifierProvider<DashboardProvider>.value(
            value: services.dashboard,
          ),
          ChangeNotifierProvider<GamificationProvider>.value(
            value: services.gamification,
          ),
          ChangeNotifierProvider<MascotProvider>.value(value: services.mascot),
        ],
        child: Consumer<AuthProvider>(
          builder: (context, auth, _) => MyApp(
            key: ValueKey(auth.isAuthenticated ? auth.accountId : 'guest'),
            authProvider: services.auth,
            profileSetupDoneListenable: services.profileSetupDone,
          ),
        ),
      ),
    );
  }
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
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final language = context.select<UserProvider, String>(
      (value) => value.settings?.language ?? 'fr',
    );
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: theme.themeMode,
      locale: Locale(language == 'en' ? 'en' : 'fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: _router,
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            statusBarBrightness: dark ? Brightness.dark : Brightness.light,
          ),
          child: ElyriiLaunch(child: GlobalErrorBoundary(child: child!)),
        );
      },
    );
  }
}
