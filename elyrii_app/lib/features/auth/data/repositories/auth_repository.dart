import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  ApiClient get client => _client;

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

    // Check if email verification is required and token is not returned
    final bool emailVerificationRequired = response['emailVerificationRequired'] == true;
    final token = response['token'] as String?;

    if (emailVerificationRequired && token == null) {
      // In this case, we don't have a token yet because the email needs verification.
      // We will throw an exception or handle it to inform the UI that verification is required.
      throw ApiException(
        statusCode: 201,
        message: response['message'] as String? ?? 'Email verification required.',
        body: response,
      );
    }

    final resolvedToken = token ?? '';
    final user = _decodeTokenPayload(resolvedToken);

    return AuthResult(
      token: resolvedToken,
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
      var payload = parts[1];
      // Pad base64 payload to multiple of 4 characters
      final padding = payload.length % 4;
      if (padding != 0) {
        payload += '=' * (4 - padding);
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      return UserModel.fromJson(json);
    } catch (e) {
      debugPrint('Error decoding token payload: $e');
      return null;
    }
  }
}
