import 'dart:async';
import 'dart:convert';

import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/network/api_exception.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:elyrii_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'offline dashboard cache has a lifetime, a period and an account',
    () async {
      var now = DateTime.utc(2026, 10, 6);
      var offline = false;
      final api = ApiClient(
        storage: SecureStorageService(),
        client: MockClient((_) async {
          if (offline) throw http.ClientException('offline');
          return http.Response(
            '{"latestMood":"happy","stats":{"streak":3}}',
            200,
          );
        }),
      );
      addTearDown(api.dispose);
      final repository = DashboardRepository(client: api, now: () => now)
        ..onUserChanged(userId: 'alice');
      expect((await repository.getDashboard()).stats.streak, 3);
      offline = true;
      final cached = await repository.getDashboard();
      expect(cached.cachedAt, now);
      await expectLater(
        repository.getDashboard(range: '7d'),
        throwsA(isA<ApiException>()),
      );
      repository.onUserChanged(userId: 'bob');
      await expectLater(
        repository.getDashboard(),
        throwsA(isA<ApiException>()),
      );
      repository.onUserChanged(userId: 'alice');
      now = now.add(const Duration(hours: 25));
      await expectLater(
        repository.getDashboard(),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test(
    '401 and malformed payloads cannot be replaced by cached dashboard success',
    () async {
      var mode = 0;
      final api = ApiClient(
        storage: SecureStorageService(),
        client: MockClient(
          (_) async => switch (mode) {
            0 => http.Response('{"latestMood":"happy"}', 200),
            1 => http.Response('{"message":"expired"}', 401),
            _ => http.Response('{"latestMood":[]}', 200),
          },
        ),
      );
      addTearDown(api.dispose);
      final repository = DashboardRepository(client: api)
        ..onUserChanged(userId: 'alice');
      await repository.getDashboard();
      mode = 1;
      await expectLater(
        repository.getDashboard(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.kind,
            'kind',
            ApiFailureKind.unauthorized,
          ),
        ),
      );
      mode = 2;
      await expectLater(
        repository.getDashboard(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.kind,
            'kind',
            ApiFailureKind.protocol,
          ),
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(
          prefs.getString('cache_dashboard_data_alice_30d')!,
        )['data']['latestMood'],
        'happy',
      );
    },
  );

  test(
    'a rejected mood rolls back, duplicate taps are blocked and retry succeeds',
    () async {
      final pending = Completer<http.Response>();
      var writes = 0;
      final api = ApiClient(
        storage: SecureStorageService(),
        client: MockClient((request) async {
          if (request.method == 'POST') {
            writes++;
            return writes == 1 ? pending.future : http.Response('{}', 200);
          }
          return http.Response('{"latestMood":"happy"}', 200);
        }),
      );
      addTearDown(api.dispose);
      final provider = DashboardProvider(
        apiClient: api,
        now: () => DateTime(2026, 10, 6),
      )..onUserChanged(userId: 'alice');
      addTearDown(provider.dispose);
      await provider.loadDashboardData();
      expect(provider.selectedMood, MoodType.happy);
      final save = provider.selectMood(MoodType.sad);
      expect(provider.isSavingMood, isTrue);
      expect(provider.selectedMood, MoodType.sad);
      expect(await provider.selectMood(MoodType.verySad), isFalse);
      pending.complete(http.Response('{"message":"rejected"}', 400));
      expect(await save, isFalse);
      expect(provider.selectedMood, MoodType.happy);
      expect(provider.moodHistory[DateTime(2026, 10, 6)], isNull);
      expect(provider.error, isNotNull);
      expect(writes, 1);
      expect(await provider.selectMood(MoodType.sad), isTrue);
      expect(writes, 2);
      expect(provider.isSavingMood, isFalse);
    },
  );
}
