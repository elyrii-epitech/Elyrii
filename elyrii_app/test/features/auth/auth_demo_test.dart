import 'dart:async';

import 'package:elyrii_app/core/config/dev_session.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _Storage extends SecureStorageService {
  String? token;
  String? userId;
  @override
  Future<void> saveAccessToken(String value) async {
    token = value;
  }

  @override
  Future<String?> getAccessToken() async => token;
  @override
  Future<void> saveUserId(String value) async {
    userId = value;
  }

  @override
  Future<String?> getUserId() async => userId;
  @override
  Future<void> setProfileSetupCompleted() async {}
  @override
  Future<void> clearAuthData() async {
    token = null;
    userId = null;
  }
}

class _Client extends ApiClient {
  _Client(SecureStorageService storage) : super(storage: storage);
  int reads = 0;
  int writes = 0;
  Future<dynamic>? profile;
  @override
  Future<dynamic> get(
    String url, {
    bool auth = true,
    Map<String, String>? queryParams,
  }) {
    reads++;
    return profile ?? Future.error(StateError('unexpected demo request'));
  }

  @override
  Future<dynamic> post(
    String url, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    writes++;
    throw StateError('unexpected demo request');
  }
}

void main() {
  test('une démo restaurée reste authentifiée sans requête backend', () async {
    final storage = _Storage();
    final client = _Client(storage);
    final provider = AuthProvider(client: client, storage: storage);
    addTearDown(provider.dispose);
    await provider.startDemoSession();
    final restored = AuthProvider(client: client, storage: storage);
    addTearDown(restored.dispose);
    await restored.restoreLocalSession();
    await restored.revalidateSession();
    expect(await restored.fetchProfile(), isTrue);
    expect(restored.isDemoSession, isTrue);
    expect(restored.user?.id, DevSession.userId);
    await restored.logout();
    expect(restored.isAuthenticated, isFalse);
    expect(storage.token, isNull);
    expect(client.reads, 0);
    expect(client.writes, 0);
  });

  test(
    'un profil ancien ne réactive pas le compte après la déconnexion',
    () async {
      final storage = _Storage();
      final stale = Completer<dynamic>();
      final client = _Client(storage)..profile = stale.future;
      final provider = AuthProvider(client: client, storage: storage);
      addTearDown(provider.dispose);
      final loading = provider.fetchProfile();
      await provider.clearLocalSession();
      stale.complete({'id': 'alice', 'email': 'alice@example.com'});
      expect(await loading, isFalse);
      expect(provider.user, isNull);
      expect(provider.isAuthenticated, isFalse);
    },
  );
}
