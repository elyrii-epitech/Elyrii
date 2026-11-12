import 'dart:async';
import 'dart:convert';

import 'package:elyrii_app/core/config/api_config.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/network/api_exception.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _token(String owner, {bool expired = false}) {
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'userId': owner,
            'email': '$owner@example.test',
            'exp':
                DateTime.now()
                    .add(Duration(hours: expired ? -1 : 1))
                    .millisecondsSinceEpoch ~/
                1000,
          }),
        ),
      )
      .replaceAll('=', '');
  return 'header.$payload.signature';
}

void main() {
  late SecureStorageService storage;
  late ApiClient api;
  late AuthProvider auth;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    storage = SecureStorageService();
  });

  void connect(Future<http.Response> Function(http.Request) handler) {
    api = ApiClient(storage: storage, client: MockClient(handler));
    auth = AuthProvider(client: api, storage: storage);
    api.onRefresh = auth.refreshAccessToken;
    addTearDown(() {
      auth.dispose();
      api.dispose();
    });
  }

  Future<void> restore({bool expired = false}) async {
    await storage.saveAccessToken(_token('alice', expired: expired));
    await storage.saveRefreshToken('refresh-original');
    await storage.saveUserId('alice');
    await auth.restoreLocalSession();
  }

  test(
    'expired restored sessions share one refresh across concurrent reads',
    () async {
      var refreshes = 0;
      final rotatedToken = _token('alice');
      connect((request) async {
        if (request.url.path == '/auth/refresh') {
          refreshes++;
          expect(jsonDecode(request.body)['refreshToken'], 'refresh-original');
          return http.Response(
            jsonEncode({
              'token': rotatedToken,
              'refreshToken': 'refresh-rotated',
            }),
            200,
          );
        }
        expect(request.headers['Authorization'], 'Bearer $rotatedToken');
        return http.Response('{}', 200);
      });
      await restore(expired: true);
      expect(auth.isAuthenticated, isTrue);
      await Future.wait([
        api.get(ApiConfig.userMeUrl),
        api.get(ApiConfig.userDashboardUrl),
      ]);
      expect(refreshes, 1);
      expect(await storage.getRefreshToken(), 'refresh-rotated');
    },
  );

  test('a 401 retries a mood write once with its unchanged payload', () async {
    var writes = 0;
    connect((request) async {
      if (request.url.path == '/auth/refresh') {
        return http.Response(
          jsonEncode({
            'token': _token('alice'),
            'refreshToken': 'refresh-rotated',
          }),
          200,
        );
      }
      writes++;
      expect(jsonDecode(request.body), {'moodType': 'happy'});
      return http.Response('{}', writes == 1 ? 401 : 201);
    });
    await restore();
    await api.post(ApiConfig.logMoodUrl, body: {'moodType': 'happy'});
    expect(writes, 2);
  });

  test(
    'a refused refresh clears the session instead of using offline success',
    () async {
      connect((_) async => http.Response('{"message":"expired"}', 401));
      await restore(expired: true);
      await expectLater(
        api.get(ApiConfig.userMeUrl),
        throwsA(isA<ApiException>()),
      );
      expect(auth.isAuthenticated, isFalse);
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    },
  );

  test('a late refresh cannot restore credentials after logout', () async {
    final started = Completer<void>();
    final reply = Completer<http.Response>();
    connect((request) async {
      if (request.url.path == '/auth/refresh') {
        started.complete();
        return reply.future;
      }
      return http.Response('{}', 200);
    });
    await restore(expired: true);
    final refreshing = auth.refreshAccessToken();
    await started.future;
    await auth.logout();
    reply.complete(
      http.Response(
        jsonEncode({
          'token': _token('alice'),
          'refreshToken': 'must-not-be-saved',
        }),
        200,
      ),
    );
    expect(await refreshing, isNull);
    expect(auth.isAuthenticated, isFalse);
    expect(await storage.getAccessToken(), isNull);
    expect(await storage.getRefreshToken(), isNull);
  });

  test('transport failures never replay a mood mutation', () async {
    var writes = 0;
    connect((_) async {
      writes++;
      return http.Response('{"message":"unavailable"}', 503);
    });
    await restore();
    await expectLater(
      api.post(ApiConfig.logMoodUrl, body: {'moodType': 'sad'}),
      throwsA(isA<ApiException>()),
    );
    expect(writes, 1);
  });
}
