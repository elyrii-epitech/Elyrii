import 'dart:convert';

import 'package:flutter/foundation.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

/// Authentication state for the app
enum AuthStatus { initial, authenticated, unauthenticated, loading }

/// Provider managing authentication state
class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository;
  final SecureStorageService _storage;

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _error;

  AuthProvider({
    required ApiClient client,
    required SecureStorageService storage,
  }) : _repository = AuthRepository(client: client),
       _storage = storage;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;

  /// Check if user has a stored token on app start
  Future<void> checkAuthStatus() async {
    final token = await _storage.getAccessToken();
    if (token == null || token.isEmpty || _isJwtExpired(token)) {
      await _storage.clearAuthData();
      _status = AuthStatus.unauthenticated;
      _user = null;
      notifyListeners();
      return;
    }

    final hasProfile = await fetchProfile();
    _status = hasProfile
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;
    if (!hasProfile) {
      _user = null;
      await _storage.clearAuthData();
    }
    notifyListeners();
  }

  /// Fetch full user profile from backend
  Future<bool> fetchProfile() async {
    try {
      final response = await _repository.client.get(ApiConfig.userMeUrl);
      _user = UserModel.fromJson(response as Map<String, dynamic>);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[AuthProvider] Failed to fetch profile: $e');
      if (e is ApiException && e.statusCode == 401) {
        await _storage.clearAuthData();
        _user = null;
      }
      return false;
    }
  }

  bool _isJwtExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final json = jsonDecode(payload) as Map<String, dynamic>;
      final exp = json['exp'];
      if (exp is! num) return true;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return exp <= now;
    } catch (e) {
      debugPrint('[AuthProvider] Invalid stored token: $e');
      return true;
    }
  }

  /// Login with email and password
  Future<bool> login({required String email, required String password}) async {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final result = await _repository.login(email: email, password: password);
      await _storage.saveAccessToken(result.token);
      if (result.user != null) {
        _user = result.user;
        await _storage.saveUserId(result.user!.id);
      }
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Connection error. Please check your network.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// Register a new account
  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    int? age,
  }) async {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final result = await _repository.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        age: age,
      );

      if (result.token.isNotEmpty) {
        await _storage.saveAccessToken(result.token);
      }

      if (result.user != null) {
        _user = result.user;
        await _storage.saveUserId(result.user!.id);
      }
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 201 &&
          e.body is Map &&
          e.body['emailVerificationRequired'] == true) {
        // Registration was successful, but email verification is required.
        // We cannot log the user in yet.
        _error = e
            .message; // "User registered successfully. Email verification required."
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false; // Return false so we don't navigate to home, user should see the message and wait for verification or go to login
      }
      _error = e.message;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Connection error. Please check your network.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// Logout and clear stored tokens
  Future<void> logout() async {
    await _repository.logout();
    await clearLocalSession();
  }

  Future<void> clearLocalSession() async {
    await _storage.clearAuthData();
    _user = null;
    _status = AuthStatus.unauthenticated;
    _error = null;
    notifyListeners();
  }

  /// Clear any displayed error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
