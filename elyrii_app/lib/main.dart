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
import 'core/config/app_config.dart';
import 'core/config/app_constants.dart';
import 'core/diagnostics/app_diagnostics.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_dimensions.dart';
import 'core/network/api_client.dart';
import 'core/services/secure_storage_service.dart';
import 'core/services/theme_provider.dart';
import 'core/widgets/error_boundary.dart';
import 'core/widgets/mascot_poster.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/journal/presentation/providers/journal_provider.dart';
import 'features/chatbot/presentation/providers/chatbot_provider.dart';
import 'features/parcours/presentation/providers/journey_provider.dart';

import 'package:elyrii_app/features/dashboard/data/accueil_activities.dart';
import 'package:elyrii_app/features/dashboard/presentation/providers/dashboard_provider.dart';

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
  final storage = SecureStorageService();
  final api = ApiClient(storage: storage);
  final theme = ThemeProvider();
  AppDependencies? dependencies;
  try {
    await Future.wait([
      initializeDateFormatting('fr'),
      initializeDateFormatting('en'),
      MascotPosterStore.initialize(),
      // Premium glass is capped off below, so its shaders are never drawn.
      LiquidGlassWidgets.initialize(
        warmUpMode: GlassWarmUpMode.never,
        enablePerformanceMonitor: false,
      ),
      theme.init(),
    ]);
    dependencies = AppDependencies(storage: storage, api: api, theme: theme);
    await dependencies.initialize();
    if (kDebugMode && const bool.fromEnvironment('CHECK_BACKEND_HEALTH')) {
      unawaited(
        api.checkHealth().catchError(
          (Object error) => AppDiagnostics.record('health_check', error),
        ),
      );
    }
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

/// The native launch screen stays up until startup resolves, so no default
/// Material frame flashes between it and the launch scene. Failures have an
/// explicit retry path; late initialization attempts are disposed.
class ApplicationBootstrap extends StatefulWidget {
  final Future<AppDependencies> Function()? initialize;
  const ApplicationBootstrap({super.key, this.initialize});
  @override
  State<ApplicationBootstrap> createState() => _ApplicationBootstrapState();
}

class _ApplicationBootstrapState extends State<ApplicationBootstrap> {
  AppDependencies? _dependencies;
  bool _failed = false;
  bool _firstFrameDeferred = true;
  int _attempt = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.deferFirstFrame();
    unawaited(_start());
  }

  void _releaseFirstFrame() {
    if (!_firstFrameDeferred) return;
    _firstFrameDeferred = false;
    WidgetsBinding.instance.allowFirstFrame();
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
      await Future.wait([
        precacheImage(const AssetImage(MascotPosterStore.asset), context),
        for (final image in MascotPosterStore.images)
          precacheImage(image, context),
      ]);
      if (!mounted || attempt != _attempt) {
        services.dispose();
        return;
      }
      setState(() => _dependencies = services);
    } catch (error) {
      AppDiagnostics.record('startup_failed', error);
      if (mounted && attempt == _attempt) {
        _attempt++;
        setState(() => _failed = true);
      }
    } finally {
      _releaseFirstFrame();
    }
  }

  @override
  void dispose() {
    _attempt++;
    _releaseFirstFrame();
    _dependencies?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = _dependencies;
    if (services == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
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
                        const SizedBox(height: AppDimensions.spacing16),
                        FilledButton(
                          onPressed: () => unawaited(_start()),
                          child: const Text('Réessayer'),
                        ),
                      ],
                    )
                  : Image.asset(
                      'assets/optimized/mascot_poster.png',
                      width: AppDimensions.accueilHeroSize,
                      height: AppDimensions.accueilHeroSize,
                      semanticLabel: 'Ouverture d’Elyrii',
                    ),
            ),
          ),
        ),
      );
    }
    return LiquidGlassWidgets.wrap(
      brightnessResolver: Theme.maybeBrightnessOf,
      adaptiveQuality: true,
      adaptiveConfig: const GlassAdaptiveScopeConfig(
        maxQuality: GlassQuality.standard,
      ),
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
          ChangeNotifierProvider<JourneyProvider>.value(
            value: services.parcours,
          ),
          ChangeNotifierProvider<DashboardProvider>.value(
            value: services.dashboard,
          ),
          ChangeNotifierProvider<AccueilActivities>.value(
            value: services.accueilActivities,
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
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _AppScrollBehavior(),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: theme.themeMode,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
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
          child: GlobalErrorBoundary(child: child!),
        );
      },
    );
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
