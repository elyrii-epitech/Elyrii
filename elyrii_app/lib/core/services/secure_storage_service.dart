import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Credentials never fall back to plaintext preferences. Platform failures are
/// surfaced to the session owner, including failed credential removal.
class SecureStorageService {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _profileSetupKey = 'profile_setup_completed';
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
            mOptions: MacOsOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  Future<bool> isAvailable() async {
    try {
      await _storage.containsKey(key: 'init_check');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveAccessToken(String token) =>
      write(key: _accessTokenKey, value: token);
  Future<String?> getAccessToken() => read(key: _accessTokenKey);
  Future<void> saveRefreshToken(String token) =>
      write(key: _refreshTokenKey, value: token);
  Future<String?> getRefreshToken() => read(key: _refreshTokenKey);
  Future<void> saveUserId(String userId) =>
      write(key: _userIdKey, value: userId);
  Future<String?> getUserId() => read(key: _userIdKey);
  Future<bool> hasAccessToken() async =>
      (await getAccessToken())?.isNotEmpty ?? false;

  Future<void> write({required String key, required String value}) async {
    await _storage.write(key: key, value: value);
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(key) && !await prefs.remove(key)) {
      throw StateError('Legacy credential removal refused');
    }
  }

  Future<String?> read({required String key}) async {
    final secure = await _storage.read(key: key);
    final prefs = await SharedPreferences.getInstance();
    if (secure != null) {
      if (prefs.containsKey(key) && !await prefs.remove(key)) {
        throw StateError('Legacy credential removal refused');
      }
      return secure;
    }
    final legacy = prefs.getString(key);
    if (legacy == null) return null;
    // One-way migration: unavailable secure storage must never open a session
    // using an old plaintext credential.
    await _storage.write(key: key, value: legacy);
    if (!await prefs.remove(key)) {
      throw StateError('Legacy credential removal refused');
    }
    return legacy;
  }

  Future<void> delete({required String key}) async {
    try {
      await _storage.delete(key: key);
    } finally {
      if (!await (await SharedPreferences.getInstance()).remove(key)) {
        throw StateError('Legacy credential removal refused');
      }
    }
  }

  Future<bool> containsKey({required String key}) async =>
      await read(key: key) != null;
  Future<bool> isProfileSetupCompleted() async {
    final owner = await getUserId();
    return owner != null && await isProfileSetupCompletedFor(owner);
  }

  Future<bool> isProfileSetupCompletedFor(String owner) async =>
      await read(key: '${_profileSetupKey}_$owner') == 'true';
  Future<void> setProfileSetupCompleted() async {
    final owner = await getUserId();
    if (owner == null || owner.isEmpty) throw StateError('No active account');
    await write(key: '${_profileSetupKey}_$owner', value: 'true');
  }

  Future<void> clearProfileSetup(String owner) =>
      delete(key: '${_profileSetupKey}_$owner');
  Future<void> clearAuthData() async {
    await Future.wait([
      delete(key: _accessTokenKey),
      delete(key: _refreshTokenKey),
      delete(key: _userIdKey),
    ]);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _accessTokenKey,
      _refreshTokenKey,
      _userIdKey,
      _profileSetupKey,
    ]) {
      await prefs.remove(key);
    }
  }
}
