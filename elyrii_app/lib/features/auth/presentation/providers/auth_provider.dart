import 'dart:convert';

import 'package:flutter/foundation.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/config/dev_session.dart';
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
    AuthRepository? repository,
    ApiClient? client,
    required SecureStorageService storage,
  }) : assert(
         repository != null || client != null,
         'repository or client must be provided',
       ),
       _repository = repository ?? AuthRepository(client: client!),
       _storage = storage;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isDemoSession => _user?.id == DevSession.userId;

  UserModel get _demoUser => const UserModel(
    id: DevSession.userId,
    email: DevSession.email,
    firstName: DevSession.firstName,
  );

  /// Offline-first session restore: storage-only, never touches the network.
  /// A syntactically valid, non-expired token is enough to enter the app;
  /// [revalidateSession] confirms it against the backend afterwards.
  Future<void> restoreLocalSession() async {
    final token = await _storage.getAccessToken();
    final valid = token != null && token.isNotEmpty && !_isJwtExpired(token);
    if (!valid) {
      await _storage.clearAuthData();
      _user = null;
      _status = AuthStatus.unauthenticated;
    } else {
      final userId = await _storage.getUserId();
      if (userId == DevSession.userId) {
        _user = _demoUser;
      }
      _status = AuthStatus.authenticated;
    }
    notifyListeners();
  }

  /// Background revalidation of the restored session.
  /// Only a definitive rejection (401) ends the session; a network failure
  /// keeps the optimistic session alive so offline use is not punished.
  Future<void> revalidateSession({
    void Function(Map<String, dynamic>)? onProfile,
  }) async {
    if (_status != AuthStatus.authenticated) return;
    final ok = await fetchProfile(onProfile: onProfile);
    if (ok || _status != AuthStatus.authenticated) return;
    final stillHasToken = await _storage.getAccessToken();
    if (stillHasToken == null) {
      // fetchProfile cleared it after a 401: the session is truly dead.
      _user = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  /// Session démo locale (développement sans backend) : stocke un JWT
  /// factice à longue durée de vie, marque l'onboarding comme complété et
  /// ouvre la session. Une erreur réseau ne la casse pas ; seul un 401
  /// réel (ou [logout]) y met fin.
  Future<void> startDemoSession() async {
    final exp =
        DateTime.now().add(const Duration(days: 3650)).millisecondsSinceEpoch ~/
        1000;
    String b64(Object json) =>
        base64Url.encode(utf8.encode(json.toString())).replaceAll('=', '');
    final demoToken =
        '${b64('{"alg":"none","typ":"JWT"}')}.'
        '${b64('{"sub":"${DevSession.userId}","exp":$exp}')}.demo';

    await _storage.saveAccessToken(demoToken);
    await _storage.saveUserId(DevSession.userId);
    await _storage.setProfileSetupCompleted();
    _user = _demoUser;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  /// Fetch full user profile from backend
  Future<bool> fetchProfile({
    void Function(Map<String, dynamic>)? onProfile,
  }) async {
    try {
      final response = await _repository.client.get(ApiConfig.userMeUrl);
      _user = UserModel.fromJson(response as Map<String, dynamic>);
      onProfile?.call(response);
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
    try {
      await _repository.logout();
    } catch (error) {
      debugPrint('[AuthProvider] Remote logout unavailable: $error');
    } finally {
      await clearLocalSession();
    }
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
