import 'dart:async';

import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/network/api_exception.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Storage extends SecureStorageService {
  String owner = 'alice';
  Completer<String?>? tokenGate;
  @override
  Future<String?> getUserId() async => owner;
  @override
  Future<String?> getAccessToken() async => tokenGate?.future ?? '$owner-token';
}

class _StreamingClient extends http.BaseClient {
  final body = StreamController<List<int>>();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(body.stream, 200);
}

Matcher kind(ApiFailureKind value) =>
    isA<ApiException>().having((e) => e.kind, 'kind', value);

void main() {
  test(
    'identical concurrent GETs share a request, later reads fetch again',
    () async {
      final gate = Completer<http.Response>();
      var calls = 0;
      final client = ApiClient(
        storage: _Storage(),
        client: MockClient((_) {
          calls++;
          return gate.future;
        }),
      );
      addTearDown(client.dispose);
      final first = client.get('https://example.test/items');
      final second = client.get('https://example.test/items');
      expect(identical(first, second), isTrue);
      gate.complete(http.Response('{"id":"one"}', 200));
      await Future.wait([first, second]);
      expect(calls, 1);
      await client.get('https://example.test/items');
      expect(calls, 2);
    },
  );
  test(
    'deadline includes credential reads and sends nothing after expiry',
    () async {
      final storage = _Storage()..tokenGate = Completer<String?>();
      var calls = 0;
      final client = ApiClient(
        storage: storage,
        timeout: const Duration(milliseconds: 30),
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      addTearDown(client.dispose);
      await expectLater(
        client.get('https://example.test/slow'),
        throwsA(kind(ApiFailureKind.timeout)),
      );
      storage.tokenGate!.complete('late-token');
      await Future<void>.delayed(Duration.zero);
      expect(calls, 0);
    },
  );
  test('deadline covers a response whose body never completes', () async {
    final transport = _StreamingClient();
    final client = ApiClient(
      storage: _Storage(),
      client: transport,
      timeout: const Duration(milliseconds: 30),
    );
    addTearDown(() async {
      client.dispose();
      await transport.body.close();
    });
    await expectLater(
      client.get('https://example.test/stream'),
      throwsA(kind(ApiFailureKind.timeout)),
    );
  });
  test('late 401 from an old account never logs out its successor', () async {
    final storage = _Storage();
    final gate = Completer<http.Response>();
    final client = ApiClient(
      storage: storage,
      client: MockClient((request) {
        expect(request.headers['Authorization'], 'Bearer alice-token');
        return gate.future;
      }),
    );
    addTearDown(client.dispose);
    var logouts = 0;
    client.onUnauthorized = (_) => logouts++;
    final pending = client.get('https://example.test/profile');
    await Future<void>.delayed(Duration.zero);
    final expectation = expectLater(
      pending,
      throwsA(kind(ApiFailureKind.cancelled)),
    );
    storage.owner = 'bob';
    client.invalidateSession();
    gate.complete(http.Response('{"message":"expired"}', 401));
    await expectation;
    expect(logouts, 0);
  });
  test(
    'a current 401 identifies its owner and cannot fall back offline',
    () async {
      final client = ApiClient(
        storage: _Storage(),
        client: MockClient((_) async => http.Response('{}', 401)),
      );
      addTearDown(client.dispose);
      String? owner;
      client.onUnauthorized = (value) => owner = value;
      await expectLater(
        client.get('https://example.test/me'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.canUseOfflineData,
            'offline fallback',
            isFalse,
          ),
        ),
      );
      expect(owner, 'alice');
    },
  );
  test(
    'invalid success JSON is a protocol failure, never an empty resource',
    () async {
      final client = ApiClient(
        storage: _Storage(),
        client: MockClient((_) async => http.Response('invalid', 200)),
      );
      addTearDown(client.dispose);
      await expectLater(
        client.get('https://example.test/me'),
        throwsA(kind(ApiFailureKind.protocol)),
      );
    },
  );
  test('failed mutations are attempted once', () async {
    var calls = 0;
    final client = ApiClient(
      storage: _Storage(),
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 503);
      }),
    );
    addTearDown(client.dispose);
    await expectLater(
      client.post('https://example.test/items'),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 1);
  });
}
