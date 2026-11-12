// Headless Flutter layout evidence. Native WebViews and plugins are mocked;
// screenshots do not measure device performance or native 3D rendering.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:elyrii_app/app/app_dependencies.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/services/theme_provider.dart';
import 'package:elyrii_app/core/storage/local_database.dart';
import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:elyrii_app/features/chatbot/presentation/providers/chatbot_provider.dart';
import 'package:elyrii_app/features/parcours/presentation/providers/journey_provider.dart';
import 'package:elyrii_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:elyrii_app/features/dashboard/data/accueil_activities.dart';
import 'package:elyrii_app/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:elyrii_app/features/journal/presentation/providers/journal_provider.dart';
import 'package:elyrii_app/features/journal/data/repositories/journal_repository.dart';
import 'package:elyrii_app/features/journal/data/models/journal_entry_model.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';
import 'package:elyrii_app/features/settings/providers/settings_provider.dart';

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
      if (r.url.path == '/user/me') {
        body = {
          'id': 'demo-user',
          'email': 'demo@elyrii.local',
          'firstName': 'Anaïs',
          'lastName': 'Martin',
        };
      }
      if (r.url.path == '/user/settings') {
        body = {
          'id': 's',
          'userId': 'demo-user',
          'themeMode': 'SYSTEM',
          'language': 'fr',
        };
      }
      if (r.url.path == '/user/mascot') {
        body = {'appearance': 'nature', 'personality': {}};
      }
      if (r.url.path == '/user/dashboard') {
        body = {
          'latestMood': null,
          'stats': {},
          'challenges': {'active': [], 'pending': []},
        };
      }
      if (r.url.path == '/user/stats') {
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
      }
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
  await app.user.loadProfile();
  await app.user.loadSettings();
  await app.user.flushed;
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
    ChangeNotifierProvider<JourneyProvider>.value(value: app.parcours),
    ChangeNotifierProvider<DashboardProvider>.value(value: app.dashboard),
    ChangeNotifierProvider<AccueilActivities>.value(
      value: app.accueilActivities,
    ),
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
