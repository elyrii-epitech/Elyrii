import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/auth/data/repositories/auth_repository.dart';
import 'package:elyrii_app/features/auth/presentation/providers/auth_provider.dart';

class _Storage extends SecureStorageService {
  bool cleared = false;
  @override
  Future<void> clearAuthData() async => cleared = true;
}

class _Repository extends AuthRepository {
  _Repository() : super(client: ApiClient(storage: _Storage()));
  @override
  Future<void> logout() async => throw const SocketException('Offline');
}

void main() {
  test(
    'logout clears local credentials even when the network is unavailable',
    () async {
      final storage = _Storage();
      final provider = AuthProvider(
        repository: _Repository(),
        storage: storage,
      );
      addTearDown(provider.dispose);
      await provider.logout();
      expect(storage.cleared, isTrue);
      expect(provider.status, AuthStatus.unauthenticated);
      expect(provider.user, isNull);
    },
  );
}
