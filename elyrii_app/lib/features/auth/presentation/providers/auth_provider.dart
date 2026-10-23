import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/config/dev_session.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository;
  final SecureStorageService _storage;
  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _accountId;
  String? _error;
  int _sessionRevision = 0;
  bool _disposed = false;
  Future<void> _credentialsTail = Future.value();
  Future<String?>? _refreshing;

  AuthProvider({
    AuthRepository? repository,
    ApiClient? client,
    required this._storage,
  }) : assert(repository != null || client != null),
       _repository = repository ?? AuthRepository(client: client!);
  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get accountId => _accountId;
  int get sessionRevision => _sessionRevision;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isDemoSession => isAuthenticated && _accountId == DevSession.userId;
  bool _current(int revision) => !_disposed && revision == _sessionRevision;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Logout cannot be overtaken by an already-started platform credential write.
  Future<T> _credentials<T>(Future<T> Function() operation) {
    final task = _credentialsTail.then((_) => operation());
    _credentialsTail = task.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return task;
  }

  Future<void> restoreLocalSession() async {
    final revision = ++_sessionRevision;
    try {
      final credentials = await Future.wait([
        _storage.getAccessToken(),
        _storage.getUserId(),
        _storage.getRefreshToken(),
      ]);
      final token = credentials[0];
      final owner = credentials[1];
      if (!_current(revision)) return;
      if (token == null ||
          (_isJwtExpired(token) && credentials[2] == null) ||
          owner == null ||
          owner.isEmpty) {
        await clearLocalSession();
        return;
      }
      _accountId = owner;
      if (owner == DevSession.userId) _user = _demoUser;
      _status = AuthStatus.authenticated;
      _notify();
    } catch (_) {
      if (!_current(revision)) return;
      _user = null;
      _accountId = null;
      _status = AuthStatus.unauthenticated;
      _error =
          'Le stockage sécurisé est indisponible. Réessaie de te connecter.';
      _notify();
    }
  }

  Future<void> revalidateSession({
    void Function(Map<String, dynamic>)? onProfile,
  }) async {
    if (isAuthenticated && !isDemoSession) {
      await fetchProfile(onProfile: onProfile);
    }
  }

  static const _demoUser = UserModel(
    id: DevSession.userId,
    email: DevSession.email,
    firstName: DevSession.firstName,
  );
  Future<void> startDemoSession() async {
    if (isLoading) return;
    final revision = _beginAuthentication();
    final exp =
        DateTime.now().add(const Duration(days: 3650)).millisecondsSinceEpoch ~/
        1000;
    String encode(Map<String, Object> value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token =
        '${encode({'alg': 'none', 'typ': 'JWT'})}.${encode({'sub': DevSession.userId, 'exp': exp})}.demo';
    try {
      if (await _commit(
        revision,
        AuthResult(token: token, user: _demoUser, message: 'Demo'),
      )) {
        await _credentials(() async {
          if (_current(revision)) await _storage.setProfileSetupCompleted();
        });
      }
    } catch (e) {
      _fail(revision, e);
    }
  }

  Future<bool> fetchProfile({
    void Function(Map<String, dynamic>)? onProfile,
  }) async {
    if (isDemoSession) {
      onProfile?.call(_demoUser.toJson());
      return true;
    }
    final revision = _sessionRevision;
    try {
      final response = await _repository.client.get(
        ApiConfig.userMeUrl,
      ) as Map<String, dynamic>;
      if (!_current(revision)) return false;
      final user = UserModel.fromJson(response);
      if (user.id.isEmpty || (_accountId != null && user.id != _accountId)) {
        throw const FormatException('Invalid account profile');
      }
      _user = user;
      _accountId = user.id;
      onProfile?.call(response);
      _notify();
      return true;
    } catch (e) {
      if (!_current(revision)) return false;
      if (e is ApiException && e.statusCode == 401) await clearLocalSession();
      return false;
    }
  }

  void acceptProfile(UserModel profile) {
    if (!isAuthenticated || profile.id != _accountId || _disposed) return;
    if (_user?.firstName == profile.firstName &&
        _user?.lastName == profile.lastName &&
        _user?.email == profile.email) {
      return;
    }
    _user = profile;
    _notify();
  }

  bool _isJwtExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final json = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final exp = json['exp'];
      return exp is! num ||
          exp <= DateTime.now().millisecondsSinceEpoch ~/ 1000;
    } catch (_) {
      return true;
    }
  }

  int _beginAuthentication() {
    final revision = ++_sessionRevision;
    _user = null;
    _accountId = null;
    _status = AuthStatus.loading;
    _error = null;
    _notify();
    return revision;
  }

  Future<bool> _commit(int revision, AuthResult result) async {
    if (!_current(revision)) return false;
    if (result.verificationRequired) {
      _status = AuthStatus.unauthenticated;
      _error = result.message;
      _notify();
      return false;
    }
    if (result.token.isEmpty ||
        result.user == null ||
        result.user!.id.isEmpty) {
      throw const FormatException(
        'Authentication response has no valid session',
      );
    }
    final committed = await _credentials(() async {
      if (!_current(revision)) return false;
      await _storage.clearAuthData();
      if (!_current(revision)) return false;
      await _storage.saveAccessToken(result.token);
      if (!_current(revision)) return false;
      if (result.refreshToken != null) {
        await _storage.saveRefreshToken(result.refreshToken!);
      }
      if (!_current(revision)) return false;
      await _storage.saveUserId(result.user!.id);
      return _current(revision);
    });
    if (!committed || !_current(revision)) return false;
    _user = result.user;
    _accountId = result.user!.id;
    _status = AuthStatus.authenticated;
    _notify();
    return true;
  }

  /// Concurrent HTTP and socket handshakes share one refresh. Credential writes
  /// use the same queue as logout, so an old response cannot revive a session.
  Future<String?> refreshAccessToken() {
    if (_refreshing != null) return _refreshing!;
    late final Future<String?> pending;
    pending = _refreshAccessToken().whenComplete(() {
      if (identical(_refreshing, pending)) _refreshing = null;
    });
    return _refreshing = pending;
  }

  Future<String?> _refreshAccessToken() async {
    if (!isAuthenticated || isDemoSession) return null;
    final revision = _sessionRevision;
    final owner = _accountId;
    final refreshToken = await _storage.getRefreshToken();
    if (!_current(revision) || refreshToken == null) return null;
    try {
      final result = await _repository.refresh(refreshToken);
      if (!_current(revision)) return null;
      if (result.user?.id != owner ||
          result.token.isEmpty ||
          result.refreshToken == null) {
        throw const FormatException('Invalid refreshed session');
      }
      return await _credentials(() async {
        if (!_current(revision)) return null;
        await _storage.saveAccessToken(result.token);
        if (!_current(revision)) return null;
        await _storage.saveRefreshToken(result.refreshToken!);
        return _current(revision) ? result.token : null;
      });
    } on ApiException catch (error) {
      if (error.statusCode == 401 && _current(revision)) {
        await clearLocalSession();
      }
      rethrow;
    }
  }

  void _fail(int revision, Object error) {
    if (!_current(revision)) return;
    _user = null;
    _accountId = null;
    _status = AuthStatus.unauthenticated;
    _error = error is ApiException
        ? error.message
        : 'Connexion impossible. Vérifie le réseau et le stockage sécurisé.';
    _notify();
  }

  Future<bool> _authenticate(Future<AuthResult> Function() request) async {
    if (isLoading) return false;
    final revision = _beginAuthentication();
    try {
      return await _commit(revision, await request());
    } catch (e) {
      if (_current(revision)) {
        try {
          await _credentials(() async {
            if (_current(revision)) await _storage.clearAuthData();
          });
        } catch (_) {
          /* Surface the authentication/storage failure below. */
        }
      }
      _fail(revision, e);
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) =>
      _authenticate(() => _repository.login(email: email, password: password));
  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    int? age,
  }) => _authenticate(
    () => _repository.register(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      age: age,
    ),
  );
  Future<void> logout() async {
    final demo = isDemoSession;
    _sessionRevision++;
    final removal = _credentials(() async {
      final token = demo ? null : await _storage.getAccessToken();
      final refreshToken = demo ? null : await _storage.getRefreshToken();
      await _storage.clearAuthData();
      return (token: token, refreshToken: refreshToken);
    });
    _user = null;
    _accountId = null;
    _status = AuthStatus.unauthenticated;
    _error = null;
    _notify();
    try {
      final credentials = await removal;
      if (!demo) {
        unawaited(
          _repository
              .logout(
                token: credentials.token,
                refreshToken: credentials.refreshToken,
              )
              .catchError((Object _) {}),
        );
      }
    } catch (_) {
      _error = 'La suppression des identifiants a échoué. Réessaie.';
      _notify();
      rethrow;
    }
  }

  Future<void> clearLocalSession() async {
    final revision = ++_sessionRevision;
    final removal = _credentials(() => _storage.clearAuthData());
    _user = null;
    _accountId = null;
    _status = AuthStatus.unauthenticated;
    _error = null;
    _notify();
    try {
      await removal;
    } catch (_) {
      if (_current(revision)) {
        _error = 'La suppression des identifiants a échoué. Réessaie avant de fermer l’application.';
        _notify();
      }
      rethrow;
    }
  }

  void clearError() {
    _error = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionRevision++;
    super.dispose();
  }
}
