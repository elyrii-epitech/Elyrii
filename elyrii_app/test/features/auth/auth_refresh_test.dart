import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:elyrii_app/core/config/api_config.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/network/api_exception.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/auth/presentation/providers/auth_provider.dart';

String _token(String owner, {bool expired = false}) {
  final expiry =
      DateTime.now()
          .add(Duration(hours: expired ? -1 : 1))
          .millisecondsSinceEpoch ~/
      1000;
  return 'header.${base64Url.encode(utf8.encode(jsonEncode({'userId': owner, 'email': '$owner@example.test', 'exp': expiry})))}.signature';
}

void main() {
  late SecureStorageService storage;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'user_id': 'alice',
      'access_token': _token('alice', expired: true),
      'refresh_token': 'old-refresh',
    });
    storage = SecureStorageService();
  });

  test('an expired restored session shares one refresh across concurrent HTTP requests', () async {
    final gate = Completer<void>();
    final started = Completer<void>();
    final token = _token('alice');
    var refreshes = 0;
    final api = ApiClient(
      storage: storage,
      client: MockClient((request) async {
        if (request.url.path == '/auth/refresh') {
          refreshes++;
          expect(jsonDecode(request.body)['refreshToken'], 'old-refresh');
          if (!started.isCompleted) started.complete();
          await gate.future;
          return http.Response(
            jsonEncode({'token': token, 'refreshToken': 'rotated-refresh'}),
            200,
          );
        }
        expect(request.headers['Authorization'], 'Bearer $token');
        return http.Response('{}', 200);
      }),
    );
    final auth = AuthProvider(client: api, storage: storage);
    api.onRefresh = auth.refreshAccessToken;
    addTearDown(auth.dispose);
    addTearDown(api.dispose);
    await auth.restoreLocalSession();
    expect(auth.isAuthenticated, isTrue);
    final requests = Future.wait([
      api.get(ApiConfig.userMeUrl),
      api.get(ApiConfig.userSettingsUrl),
      api.get(ApiConfig.userDashboardUrl),
    ]);
    await started.future;
    expect(refreshes, 1);
    gate.complete();
    await requests;
    expect(refreshes, 1);
    expect(await storage.getAccessToken(), token);
    expect(await storage.getRefreshToken(), 'rotated-refresh');
  });

  test('a refresh finishing after logout cannot restore credentials', () async {
    final gate = Completer<void>();
    final started = Completer<void>();
    final api = ApiClient(
      storage: storage,
      client: MockClient((request) async {
        if (request.url.path == '/auth/refresh') {
          started.complete();
          await gate.future;
          return http.Response(
            jsonEncode({
              'token': _token('alice'),
              'refreshToken': 'late-refresh',
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      }),
    );
    final auth = AuthProvider(client: api, storage: storage);
    addTearDown(auth.dispose);
    addTearDown(api.dispose);
    await auth.restoreLocalSession();
    final refreshing = auth.refreshAccessToken();
    await started.future;
    await auth.logout();
    gate.complete();
    expect(await refreshing, isNull);
    expect(auth.isAuthenticated, isFalse);
    expect(await storage.getAccessToken(), isNull);
    expect(await storage.getRefreshToken(), isNull);
  });

  test('a rejected refresh clears the expired session and does not retry the protected request', () async {
    var protectedRequests = 0;
    final api = ApiClient(
      storage: storage,
      client: MockClient((request) async {
        if (request.url.path != '/auth/refresh') protectedRequests++;
        return http.Response('{"error":"Invalid refresh token"}', 401);
      }),
    );
    final auth = AuthProvider(client: api, storage: storage);
    api.onRefresh = auth.refreshAccessToken;
    addTearDown(auth.dispose);
    addTearDown(api.dispose);
    await auth.restoreLocalSession();
    await expectLater(
      api.get(ApiConfig.userMeUrl),
      throwsA(isA<ApiException>()),
    );
    expect(protectedRequests, 0);
    expect(auth.isAuthenticated, isFalse);
    expect(await storage.getRefreshToken(), isNull);
  });
}
