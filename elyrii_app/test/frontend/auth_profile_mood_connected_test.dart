import 'dart:convert';
import 'dart:io';

import 'package:elyrii_app/core/config/api_config.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:elyrii_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:elyrii_app/features/settings/providers/settings_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  const enabled = bool.fromEnvironment('MOBILE_API_INTEGRATION');
  test('new frontend restores real profile and mood, refreshes, and isolates accounts', () async {
    const base = String.fromEnvironment(
      'MOBILE_TEST_API_URL',
      defaultValue: 'http://127.0.0.1:3188',
    );
    expect(Uri.parse(base).host, '127.0.0.1');
    final oldBase = ApiConfig.baseUrl;
    final overrides = HttpOverrides.current;
    HttpOverrides.global = null;
    ApiConfig.setBaseUrl(base);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    const password = 'NativeSecret123';
    final firstEmail = 'dart-${const Uuid().v4()}@example.test';
    final secondEmail = 'dart-${const Uuid().v4()}@example.test';
    final storage = SecureStorageService();
    final api = ApiClient(storage: storage);
    var auth = AuthProvider(client: api, storage: storage);
    var profile = UserProvider(client: api);
    var dashboard = DashboardProvider(apiClient: api);
    void bind() {
      api.onRefresh = auth.refreshAccessToken;
      profile.onUserChanged(userId: auth.accountId);
      dashboard.onUserChanged(userId: auth.accountId);
    }

    addTearDown(() async {
      for (final email in [firstEmail, secondEmail]) {
        try {
          await auth.login(email: email, password: password);
          await api.delete(
            ApiConfig.userAccountUrl,
            body: {'password': password},
          );
        } catch (_) {
          // A failed signup may leave no account to clean up.
        }
      }
      await auth.clearLocalSession();
      auth.dispose();
      profile.dispose();
      dashboard.dispose();
      api.dispose();
      ApiConfig.setBaseUrl(oldBase);
      HttpOverrides.global = overrides;
    });

    expect(
      await auth.register(
        email: firstEmail,
        password: password,
        firstName: 'Camille',
        lastName: 'Fixture',
      ),
      isTrue,
      reason: auth.error,
    );
    final firstOwner = auth.accountId;
    expect(await storage.getRefreshToken(), isNotEmpty);
    bind();
    expect(
      await profile.updateProfile(
        firstName: 'Camille connecté',
        age: 25,
        bio: 'Saved through the new frontend',
        pronouns: 'iel',
        wellnessGoal: 'calm',
        timezone: 'Europe/Paris',
      ),
      isTrue,
      reason: profile.error,
    );
    expect(
      await dashboard.selectMood(MoodType.happy),
      isTrue,
      reason: dashboard.error,
    );

    // Recreate application state while preserving only platform credentials.
    // Clear preference caches too: the following values must come from HTTP.
    await (await SharedPreferences.getInstance()).clear();
    auth.dispose();
    profile.dispose();
    dashboard.dispose();
    auth = AuthProvider(client: api, storage: storage);
    profile = UserProvider(client: api);
    dashboard = DashboardProvider(apiClient: api);
    await auth.restoreLocalSession();
    expect(auth.accountId, firstOwner);
    bind();
    await Future.wait([profile.loadProfile(), dashboard.loadDashboardData()]);
    expect(profile.profile?.firstName, 'Camille connecté');
    expect(profile.profile?.bio, 'Saved through the new frontend');
    expect(dashboard.selectedMood, MoodType.happy);
    expect(dashboard.history.values.any((day) => day.moodLogs > 0), isTrue);

    final oldRefresh = await storage.getRefreshToken();
    final token = (await storage.getAccessToken())!;
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
    ) as Map;
    payload['exp'] = 1;
    await storage.saveAccessToken(
      'header.${base64Url.encode(utf8.encode(jsonEncode(payload)))}.expired',
    );
    await Future.wait([profile.loadProfile(), dashboard.refresh()]);
    expect(profile.profile?.firstName, 'Camille connecté');
    expect(dashboard.selectedMood, MoodType.happy);
    expect(await storage.getRefreshToken(), isNot(oldRefresh));

    await auth.logout();
    expect(
      await auth.register(
        email: secondEmail,
        password: password,
        firstName: 'Other',
        lastName: 'Fixture',
      ),
      isTrue,
      reason: auth.error,
    );
    bind();
    await Future.wait([profile.loadProfile(), dashboard.loadDashboardData()]);
    expect(profile.profile?.id, isNot(firstOwner));
    expect(profile.profile?.bio, isNull);
    expect(dashboard.selectedMood, isNull);
    expect(dashboard.history, isEmpty);
  }, skip: !enabled);
}
