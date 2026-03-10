import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/secure_storage_service.dart';
import 'api_exception.dart';

/// HTTP client with automatic token management
/// All requests go through the gateway
class ApiClient {
  final http.Client _client;
  final SecureStorageService _storage;

  static const int _timeoutSeconds = 30;

  ApiClient({required SecureStorageService storage, http.Client? client})
      : _storage = storage,
        _client = client ?? http.Client();

  Map<String, String> _baseHeaders() => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Future<Map<String, String>> _authHeaders() async {
    final headers = _baseHeaders();
    final token = await _storage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Perform a GET request
  Future<dynamic> get(
    String url, {
    bool auth = true,
    Map<String, String>? queryParams,
  }) async {
    final uri = queryParams != null
        ? Uri.parse(url).replace(queryParameters: queryParams)
        : Uri.parse(url);
    final headers = auth ? await _authHeaders() : _baseHeaders();
    final response = await _client
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: _timeoutSeconds));
    return _handleResponse(response);
  }

  /// Perform a POST request
  Future<dynamic> post(
    String url, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final headers = auth ? await _authHeaders() : _baseHeaders();
    final response = await _client
        .post(
          Uri.parse(url),
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: _timeoutSeconds));
    return _handleResponse(response);
  }

  /// Perform a PUT request
  Future<dynamic> put(
    String url, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final headers = auth ? await _authHeaders() : _baseHeaders();
    final response = await _client
        .put(
          Uri.parse(url),
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: _timeoutSeconds));
    return _handleResponse(response);
  }

  /// Perform a DELETE request
  Future<dynamic> delete(String url, {bool auth = true}) async {
    final headers = auth ? await _authHeaders() : _baseHeaders();
    final response = await _client
        .delete(Uri.parse(url), headers: headers)
        .timeout(const Duration(seconds: _timeoutSeconds));
    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    dynamic body;
    try {
      body = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};
    } catch (e) {
      body = <String, dynamic>{'raw': response.body};
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    final errorMessage = body is Map
        ? (body['error']?.toString() ?? 'Request failed')
        : 'Request failed';
    debugPrint('[ApiClient] ${response.statusCode}: $errorMessage');
    throw ApiException(
      statusCode: response.statusCode,
      message: errorMessage,
      body: body,
    );
  }

  /// Clean up resources
  void dispose() {
    _client.close();
  }
}
