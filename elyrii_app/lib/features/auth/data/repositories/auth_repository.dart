import 'dart:convert';
import '../../../../core/network/api_client.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_exception.dart';
import '../models/user_model.dart';

/// Result type for auth operations
class AuthResult {
  final String token;
  final UserModel? user;
  final String message;

  const AuthResult({required this.token, this.user, required this.message});
}

/// Repository handling authentication API calls
class AuthRepository {
  final ApiClient _client;

  AuthRepository({required ApiClient client}) : _client = client;

  /// Login with email and password
  /// Returns JWT access token on success
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      ApiConfig.loginUrl,
      body: {'email': email, 'password': password},
      auth: false,
    ) as Map<String, dynamic>;
    final token = response['token'] as String? ?? '';
    final user = _decodeTokenPayload(token);
    return AuthResult(
      token: token,
      user: user,
      message: response['message'] as String? ?? 'Login successful',
    );
  }

  /// Register a new user
  Future<AuthResult> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    int? age,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
    };
    if (age != null) body['age'] = age;
    final response = await _client.post(ApiConfig.registerUrl,
        body: body, auth: false) as Map<String, dynamic>;
    final token = response['token'] as String? ?? '';
    final user = _decodeTokenPayload(token);
    return AuthResult(
      token: token,
      user: user,
      message: response['message'] as String? ?? 'Registration successful',
    );
  }

  /// Logout the current user
  Future<void> logout() async {
    try {
      await _client.post(ApiConfig.logoutUrl);
    } on ApiException {
      // Ignore errors on logout — token will be cleared locally
    }
  }

  /// Decode JWT payload to extract user info (userId, email)
  UserModel? _decodeTokenPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      return UserModel.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
