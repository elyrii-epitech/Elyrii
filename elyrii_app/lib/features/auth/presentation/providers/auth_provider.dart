import 'package:flutter/foundation.dart';
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
    final hasToken = await _storage.hasAccessToken();
    if (hasToken) {
      _status = AuthStatus.authenticated;
      final userId = await _storage.getUserId();
      if (userId != null) {
        _user = UserModel(id: userId, email: '');
      }
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
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

  /// Logout and clear stored tokens
  Future<void> logout() async {
    await _repository.logout();
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
