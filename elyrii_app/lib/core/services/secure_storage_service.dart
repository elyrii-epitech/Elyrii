import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for securely storing sensitive data (tokens, credentials)
/// Uses flutter_secure_storage which encrypts data.
/// Fallbacks to SharedPreferences (unencrypted) on macOS if entitlements are missing (-34018).
class SecureStorageService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';

  final FlutterSecureStorage _storage;
  SharedPreferences? _prefs;
  bool _useFallback = false;

  SecureStorageService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock_this_device,
          ),
          mOptions: MacOsOptions(
            accessibility: KeychainAccessibility.first_unlock_this_device,
          ),
        );

  Future<void> _initFallback() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
  }

  // ==================== Initialization Check ====================

  /// Check if the storage service is available and working
  Future<bool> isAvailable() async {
    try {
      if (_useFallback) return true;
      // Attempt a dummy read to check access
      await _storage.containsKey(key: 'init_check');
      return true;
    } catch (e) {
      debugPrint('SecureStorageService not available, using fallback: $e');
      _useFallback = true;
      return true;
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
      if (_useFallback) {
        await _initFallback();
        await _prefs?.setString(key, value);
        return;
      }
      await _storage.write(key: key, value: value);
    } on PlatformException catch (e) {
      if (e.code == '-34018' || e.message?.contains('-34018') == true) {
        debugPrint(
            'SecureStorage: Keychain inaccessible. Using SharedPreferences fallback.');
        _useFallback = true;
        await _initFallback();
        await _prefs?.setString(key, value);
      } else {
        rethrow;
      }
    } catch (e) {
      debugPrint('Error writing to SecureStorage ($key): $e');
      rethrow;
    }
  }

  /// Read any sensitive value
  Future<String?> read({required String key}) async {
    try {
      if (_useFallback) {
        await _initFallback();
        return _prefs?.getString(key);
      }
      return await _storage.read(key: key);
    } catch (e) {
      // If read fails, try fallback
      await _initFallback();
      final value = _prefs?.getString(key);
      if (value != null) {
        _useFallback = true;
        return value;
      }
      debugPrint('Error reading from SecureStorage ($key): $e');
      return null;
    }
  }

  /// Delete a specific key
  Future<void> delete({required String key}) async {
    try {
      await _storage.delete(key: key);
      await _initFallback();
      await _prefs?.remove(key);
    } catch (e) {
      await _initFallback();
      await _prefs?.remove(key);
    }
  }

  /// Check if a key exists
  Future<bool> containsKey({required String key}) async {
    try {
      if (_useFallback) {
        await _initFallback();
        return _prefs?.containsKey(key) ?? false;
      }
      return await _storage.containsKey(key: key);
    } catch (e) {
      await _initFallback();
      return _prefs?.containsKey(key) ?? false;
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
    }
  }

  /// Clear all stored data
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      await _initFallback();
      final keys = _prefs?.getKeys() ?? {};
      for (final key in keys) {
        await _prefs?.remove(key);
      }
    } catch (e) {
      await _initFallback();
      await _prefs?.clear();
    }
  }
}
