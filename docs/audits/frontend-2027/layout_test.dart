// Headless Flutter layout evidence. Native WebViews and plugins are mocked;
// screenshots do not measure device performance or native 3D rendering.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:elyrii_app/app/app_dependencies.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/services/theme_provider.dart';
import 'package:elyrii_app/core/storage/local_database.dart';
import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/features/auth/presentation/pages/login_page.dart';
import 'package:elyrii_app/features/auth/presentation/pages/register_page.dart';
import 'package:elyrii_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:elyrii_app/features/chatbot/presentation/pages/chatbot_page.dart';
import 'package:elyrii_app/features/chatbot/presentation/providers/chatbot_provider.dart';
import 'package:elyrii_app/features/coach/presentation/pages/coach_page.dart';
import 'package:elyrii_app/features/coach/presentation/providers/coach_provider.dart';
import 'package:elyrii_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:elyrii_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:elyrii_app/features/gamification/presentation/pages/challenges_page.dart';
import 'package:elyrii_app/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:elyrii_app/features/journal/presentation/pages/journal_page.dart';
import 'package:elyrii_app/features/journal/presentation/providers/journal_provider.dart';
import 'package:elyrii_app/features/journal/data/repositories/journal_repository.dart';
import 'package:elyrii_app/features/journal/data/models/journal_entry_model.dart';
import 'package:elyrii_app/features/mascot/presentation/pages/mascot_customization_page.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';
import 'package:elyrii_app/features/meditation/presentation/pages/meditation_page.dart';
import 'package:elyrii_app/features/profile_setup/presentation/pages/profile_setup_page.dart';
import 'package:elyrii_app/features/profile_setup/presentation/pages/edit_profile_page.dart';
import 'package:elyrii_app/features/profile_setup/presentation/pages/avatar_picker_page.dart';
import 'package:elyrii_app/features/reviews/presentation/pages/reviews_page.dart';
import 'package:elyrii_app/features/settings/pages/settings_page.dart';
import 'package:elyrii_app/features/settings/providers/settings_provider.dart';

const auditDir = String.fromEnvironment(
  'AUDIT_OUTPUT',
  defaultValue: '/workspace/scratch/frontend-audit-2027',
);
final records = <Map<String, Object?>>[];
final visualJournals = <AppDependencies, JournalProvider>{};

class LayoutJournalRepository extends JournalRepository {
  LayoutJournalRepository(ApiClient api) : super(client: api);
  @override
  Future<List<JournalEntryModel>> getEntries({
    DateTime? startDate,
    DateTime? endDate,
  }) async => [];
  @override
  Future<List<JournalEntryModel>> getCachedEntries({String? owner}) async => [];
}

Future<AppDependencies> fixture() async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  sqfliteFfiInit();
  LocalDatabase.factoryOverride = databaseFactoryFfi;
  LocalDatabase.pathOverride = (_) => inMemoryDatabasePath;
  final storage = SecureStorageService();
  final api = ApiClient(
    storage: storage,
    client: MockClient((r) async {
      Object body = <Object>[];
      if (r.url.path == '/user/me')
        body = {
          'id': 'demo-user',
          'email': 'demo@elyrii.local',
          'firstName': 'Anaïs',
          'lastName': 'Martin',
        };
      if (r.url.path == '/user/settings')
        body = {
          'id': 's',
          'userId': 'demo-user',
          'themeMode': 'SYSTEM',
          'language': 'fr',
        };
      if (r.url.path == '/user/mascot')
        body = {'appearance': 'nature', 'personality': {}};
      if (r.url.path == '/user/dashboard')
        body = {
          'latestMood': null,
          'stats': {},
          'challenges': {'active': [], 'pending': []},
        };
      if (r.url.path == '/user/stats')
        body = {
          'rangeDays': 30,
          'streak': 7,
          'moodLogsCount': 12,
          'journalEntriesCount': 5,
          'moodTrend7Days': [
            {'day': '2026-10-10', 'count': 3},
          ],
          'moodDistribution': [
            {'moodType': 'happy', 'count': 5},
            {'moodType': 'sad', 'count': 2},
          ],
          'activityTimeline': [
            {'day': '2026-10-10', 'moodLogs': 3, 'journalEntries': 1},
          ],
        };
      return http.Response(jsonEncode(body), 200);
    }),
  );
  final app = AppDependencies(
    storage: storage,
    api: api,
    theme: ThemeProvider(),
  );
  await app.auth.startDemoSession();
  await app.chat.ready;
  await app.mascot.flushed;
  await app.dashboard.loadDashboardData();
  await app.gamification.loadAll();
  visualJournals[app] = JournalProvider(
    repository: LayoutJournalRepository(api),
  );
  return app;
}

Widget host(
  AppDependencies app,
  Widget page,
  GlobalKey key,
  bool dark,
  double scale,
) => MultiProvider(
  providers: [
    Provider<AppDependencies>.value(value: app),
    Provider<ApiClient>.value(value: app.api),
    Provider<SecureStorageService>.value(value: app.storage),
    ListenableProvider<ValueNotifier<bool>>.value(value: app.profileSetupDone),
    ChangeNotifierProvider<ThemeProvider>.value(value: app.theme),
    ChangeNotifierProvider<AuthProvider>.value(value: app.auth),
    ChangeNotifierProvider<UserProvider>.value(value: app.user),
    ChangeNotifierProvider<ChatbotProvider>.value(value: app.chat),
    ChangeNotifierProvider<JournalProvider>.value(value: visualJournals[app]!),
    ChangeNotifierProvider<CoachProvider>.value(value: app.coach),
    ChangeNotifierProvider<DashboardProvider>.value(value: app.dashboard),
    ChangeNotifierProvider<GamificationProvider>.value(value: app.gamification),
    ChangeNotifierProvider<MascotProvider>.value(value: app.mascot),
  ],
  child: RepaintBoundary(
    key: key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
          padding: const EdgeInsets.only(top: 24, bottom: 20),
        ),
        child: child!,
      ),
      home: page,
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('fr');
    final loader = FontLoader('Poppins')
      ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-Bold.ttf'));
    await loader.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
    Directory('$auditDir/screenshots').createSync(recursive: true);
  });
  tearDownAll(
    () => File('$auditDir/layout.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(records)),
  );
  final pages = <String, Widget>{
    'login': const LoginPage(),
    'register': const RegisterPage(),
    'dashboard': const DashboardPage(),
    'challenges': const ChallengesPage(),
    'journal': const JournalPage(),
    'chat': const ChatbotPage(),
    'coach': const CoachPage(),
    'meditation': const MeditationPage(),
    'mascot': const MascotCustomizationPage(),
    'profile-setup': const ProfileSetupPage(),
    'profile-edit': const EditProfilePage(),
    'avatar': const AvatarPickerPage(),
    'settings': const SettingsPage(),
    'reviews': const ReviewsPage(),
  };
  for (final cfg in [
    (name: 'mobile', size: const Size(390, 844), scale: 1.0, dark: false),
    (
      name: 'small-text200',
      size: const Size(320, 568),
      scale: 2.0,
      dark: false,
    ),
    (name: 'dark-text200', size: const Size(390, 844), scale: 2.0, dark: true),
    (
      name: 'tablet-landscape',
      size: const Size(1024, 768),
      scale: 1.0,
      dark: false,
    ),
  ]) {
    for (final page in pages.entries) {
      testWidgets('${page.key} ${cfg.name}', (tester) async {
        tester.view.physicalSize = cfg.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final app = await tester.runAsync(fixture);
        app!.theme.setThemeMode(
          cfg.dark ? ThemeMode.dark : ThemeMode.light,
          persist: false,
        );
        final errors = <String>[];
        final previous = FlutterError.onError;
        final diagnostics = <String>[];
        FlutterError.onError = (details) {
          errors.add(details.exceptionAsString());
          diagnostics.add(details.toString());
        };
        final key = GlobalKey();
        try {
          await tester.pumpWidget(
            host(app, page.value, key, cfg.dark, cfg.scale),
          );
          await tester.pump();
          await tester.pump(const Duration(seconds: 2));
          await tester.runAsync(() async {
            await app.chat.ready;
            await app.mascot.flushed;
          });
          await tester.pump();
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final png = await tester.runAsync(() async {
            final picture = await boundary.toImage(pixelRatio: 1);
            final bytes = await picture.toByteData(
              format: ui.ImageByteFormat.png,
            );
            picture.dispose();
            return bytes!.buffer.asUint8List();
          });
          File('$auditDir/screenshots/${page.key}-${cfg.name}.png')
              .writeAsBytesSync(png!);
          records.add({
            'page': page.key,
            'configuration': cfg.name,
            'width': cfg.size.width,
            'height': cfg.size.height,
            'textScale': cfg.scale,
            'errors': errors.toList(),
            'diagnostics': diagnostics,
          });
          print('LAYOUT ${page.key} ${cfg.name}: ${errors.length} errors');
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          FlutterError.onError = previous;
          visualJournals.remove(app)!.dispose();
          await tester.runAsync(() async {
            app.dispose();
            await app.chat.flushed;
            await app.history.close();
            await app.journalStore.close();
          });
        }
      });
    }
  }
}
