import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for securely storing sensitive data (tokens, credentials)
/// Uses flutter_secure_storage which encrypts data using:
/// - iOS: Keychain
/// - Android: Custom AES encryption (migrated from EncryptedSharedPreferences)
class SecureStorageService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';

  final FlutterSecureStorage _storage;

  SecureStorageService()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(
          // EncryptedSharedPreferences is deprecated in v10 and removed.
          // data is migrated automatically to AES.
        ),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );

  // ==================== Initialization Check ====================

  /// Check if the storage service is available and working
  Future<bool> isAvailable() async {
    try {
      // Attempt a dummy read to check access
      await _storage.containsKey(key: 'init_check');
      return true;
    } catch (e) {
      debugPrint('SecureStorageService not available: $e');
      return false;
    }
  }

  // ==================== Token Management ====================

  /// Store the access token securely
  Future<void> saveAccessToken(String token) async {
    await write(key: _accessTokenKey, value: token);
  }

  /// Retrieve the access token
  Future<String?> getAccessToken() async {
    return await read(key: _accessTokenKey);
  }

  /// Store the refresh token securely
  Future<void> saveRefreshToken(String token) async {
    await write(key: _refreshTokenKey, value: token);
  }

  /// Retrieve the refresh token
  Future<String?> getRefreshToken() async {
    return await read(key: _refreshTokenKey);
  }

  /// Check if user has a valid stored token
  Future<bool> hasAccessToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ==================== User Data ====================

  /// Store user ID securely
  Future<void> saveUserId(String userId) async {
    await write(key: _userIdKey, value: userId);
  }

  /// Retrieve user ID
  Future<String?> getUserId() async {
    return await read(key: _userIdKey);
  }

  // ==================== Generic Methods ====================

  /// Store any sensitive value
  Future<void> write({required String key, required String value}) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('Error writing to SecureStorage ($key): $e');
      rethrow;
    }
  }

  /// Read any sensitive value
  Future<String?> read({required String key}) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('Error reading from SecureStorage ($key): $e');
      return null;
    }
  }

  /// Delete a specific key
  Future<void> delete({required String key}) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('Error deleting from SecureStorage ($key): $e');
      rethrow;
    }
  }

  /// Check if a key exists
  Future<bool> containsKey({required String key}) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (e) {
      debugPrint('Error checking key in SecureStorage ($key): $e');
      return false;
    }
  }

  // ==================== Session Management ====================

  /// Clear all authentication data (logout)
  Future<void> clearAuthData() async {
    try {
      await Future.wait([
        delete(key: _accessTokenKey),
        delete(key: _refreshTokenKey),
        delete(key: _userIdKey),
      ]);
    } catch (e) {
      debugPrint('Error clearing auth data: $e');
      // Non-critical, just log
    }
  }

  /// Clear all stored data
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('Error deleting all from SecureStorage: $e');
      rethrow;
    }
  }
}
