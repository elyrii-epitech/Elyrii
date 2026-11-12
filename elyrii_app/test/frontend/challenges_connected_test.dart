import 'dart:io';

import 'package:elyrii_app/core/config/api_config.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:elyrii_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:elyrii_app/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:elyrii_app/features/journal/presentation/providers/journal_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  test('challenges follow confirmed mood and journal activity, restore the garden and isolate accounts', () async {
    const base = String.fromEnvironment(
      'MOBILE_TEST_API_URL',
      defaultValue: 'http://127.0.0.1:3188',
    );
    expect(Uri.parse(base).host, '127.0.0.1');
    final previousBase = ApiConfig.baseUrl,
        previousOverrides = HttpOverrides.current;
    ApiConfig.setBaseUrl(base);
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final storage = SecureStorageService(),
        api = ApiClient(storage: SecureStorageService());
    final auth = AuthProvider(client: api, storage: storage);
    api.onRefresh = auth.refreshAccessToken;
    final emails = List.generate(
      2,
      (_) => 'dart-challenges-${const Uuid().v4()}@example.test',
    );
    const password = 'ChallengeSecret123';
    var garden = GamificationProvider(
      client: api,
      now: () => DateTime.utc(2026, 11, 10, 12),
    );
    Future<void> activityRefresh = Future.value();
    void activitySaved() {
      activityRefresh = garden.refreshAfterActivity();
    }

    final dashboard = DashboardProvider(
      apiClient: api,
      onMoodSaved: activitySaved,
    );
    final journal = JournalProvider(client: api, onEntrySaved: activitySaved);
    addTearDown(() async {
      for (final email in emails) {
        try {
          await auth.login(email: email, password: password);
          await api.delete(
            ApiConfig.userAccountUrl,
            body: {'password': password},
          );
        } catch (_) {}
      }
      await auth.clearLocalSession();
      auth.dispose();
      garden.dispose();
      dashboard.dispose();
      journal.dispose();
      api.dispose();
      ApiConfig.setBaseUrl(previousBase);
      HttpOverrides.global = previousOverrides;
    });
    expect(
      await auth.register(
        email: emails[0],
        password: password,
        firstName: 'Garden',
        lastName: 'Fixture',
      ),
      isTrue,
      reason: auth.error,
    );
    final owner = auth.accountId!;
    garden.onUserChanged(userId: owner);
    dashboard.onUserChanged(userId: owner);
    journal.onUserChanged(owner);
    await garden.loadAll();
    expect(garden.error, isNull);
    final first = garden.availableChallenges.singleWhere(
      (row) => row.title == 'Premier pas',
    );
    expect(await garden.startChallenge(first.id), isTrue, reason: garden.error);
    expect(garden.activeChallenges.single.template?.title, 'Premier pas');
    expect(garden.activeChallenges.single.progressFraction, 0);
    expect(
      await dashboard.selectMood(MoodType.happy),
      isTrue,
      reason: dashboard.error,
    );
    await activityRefresh;
    expect(garden.completedChallenges.single.template?.title, 'Premier pas');
    expect(garden.completedChallenges.single.progressFraction, 1);
    expect(garden.activeChallenges, isEmpty);

    final note = garden.availableChallenges.singleWhere(
      (row) => row.title == 'Première page',
    );
    expect(await garden.startChallenge(note.id), isTrue);
    expect(
      await journal.createEntry(
        title: 'Un moment pour moi',
        content: 'Une note enregistrée sur le serveur.',
      ),
      isNotNull,
      reason: journal.error,
    );
    await activityRefresh;
    expect(garden.completedChallenges, hasLength(2));
    expect(garden.activeChallenges, isEmpty);

    final proposals = <Map<String, dynamic>>[];
    for (var i = 0; i < 2; i++) {
      proposals.add(
        Map<String, dynamic>.from(
          await api.post(
            ApiConfig.proposalsUrl,
            body: {
              'title': 'Proposition fixture $i',
              'description': 'Un objectif test',
              'conditions': [
                {'type': 'mood_count', 'target': 10},
              ],
              'aggregator': 'ALL',
            },
          ) as Map,
        ),
      );
    }
    await garden.loadAll(force: true);
    expect(garden.proposals, hasLength(2));
    final accepted = (proposals[0]['userChallenge'] as Map)['id'] as String;
    final rejected = (proposals[1]['userChallenge'] as Map)['id'] as String;
    expect(await garden.acceptChallenge(accepted), isTrue);
    expect(
      garden.activeChallenges.single.displayTitle,
      'Proposition fixture 0',
    );
    expect(garden.activeChallenges.single.progressFraction, 0.1);
    expect(await garden.rejectChallenge(rejected), isTrue);
    await garden.loadAll(force: true);
    expect(garden.proposals, isEmpty);

    garden.dispose();
    garden = GamificationProvider(client: api)..onUserChanged(userId: owner);
    await garden.loadAll();
    expect(garden.completedChallenges, hasLength(2));
    expect(
      garden.activeChallenges.single.displayTitle,
      'Proposition fixture 0',
    );
    expect(
      garden.availableChallenges.any(
        (row) => row.id == first.id || row.id == note.id,
      ),
      isFalse,
    );

    await auth.logout();
    expect(
      await auth.register(
        email: emails[1],
        password: password,
        firstName: 'Other',
        lastName: 'Fixture',
      ),
      isTrue,
    );
    garden.onUserChanged(userId: auth.accountId);
    await garden.loadAll();
    expect(garden.activeChallenges, isEmpty);
    expect(garden.completedChallenges, isEmpty);
    expect(garden.proposals, isEmpty);
    expect(garden.availableChallenges.any((row) => row.id == first.id), isTrue);
  }, skip: !const bool.fromEnvironment('MOBILE_API_INTEGRATION'));
}
