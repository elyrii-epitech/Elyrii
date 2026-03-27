import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureStorageService', () {
    late SecureStorageService service;

    setUp(() {
      // Mock basic implementation for testing
      FlutterSecureStorage.setMockInitialValues({});
      service = SecureStorageService();
    });

    test('should save and retrieve access token', () async {
      const token = 'test_access_token';
      await service.saveAccessToken(token);

      final retrieved = await service.getAccessToken();
      expect(retrieved, equals(token));
    });

    test('should return null when no token exists', () async {
      final retrieved = await service.getAccessToken();
      expect(retrieved, isNull);
    });

    test('hasAccessToken should return true when token exists', () async {
      await service.saveAccessToken('token');
      expect(await service.hasAccessToken(), isTrue);
    });

<<<<<<< HEAD
    test(
      'hasAccessToken should return false when token does not exist',
      () async {
        expect(await service.hasAccessToken(), isFalse);
      },
    );
>>>>>>> dev
=======
    test(
      'hasAccessToken should return false when token does not exist',
      () async {
        expect(await service.hasAccessToken(), isFalse);
      },
    );
=======
    test(
      'hasAccessToken should return false when token does not exist',
      () async {
        expect(await service.hasAccessToken(), isFalse);
      },
    );
>>>>>>> dev

    test('should save and retrieve refresh token', () async {
      const token = 'test_refresh_token';
      await service.saveRefreshToken(token);

      final retrieved = await service.getRefreshToken();
      expect(retrieved, equals(token));
    });

    test('should save and retrieve user id', () async {
      const userId = 'user_123';
      await service.saveUserId(userId);

      final retrieved = await service.getUserId();
      expect(retrieved, equals(userId));
    });

    test('clearAuthData should remove all tokens and user id', () async {
      await service.saveAccessToken('access');
      await service.saveRefreshToken('refresh');
      await service.saveUserId('123');

      await service.clearAuthData();

      expect(await service.getAccessToken(), isNull);
      expect(await service.getRefreshToken(), isNull);
      expect(await service.getUserId(), isNull);
    });

    test('isAvailable should return true in mock environment', () async {
      // Logic in isAvailable sets a dummy key, mock environment allows basic operations
      final available = await service.isAvailable();
      expect(available, isTrue);
    });
  });
}
