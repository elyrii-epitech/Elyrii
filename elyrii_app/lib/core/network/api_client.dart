import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/api_config.dart';
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
    debugPrint('[ApiClient] GET $uri (auth: $auth)');
    final headers = auth ? await _authHeaders() : _baseHeaders();
    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: _timeoutSeconds));
      return _handleResponse(response);
    } catch (e) {
      debugPrint('[ApiClient] GET $uri failed: $e');
      rethrow;
    }
  }

  /// Perform a POST request
  Future<dynamic> post(
    String url, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    debugPrint('[ApiClient] POST $url (auth: $auth)');
    final headers = auth ? await _authHeaders() : _baseHeaders();
    try {
      final response = await _client
          .post(
            Uri.parse(url),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: _timeoutSeconds));
      return _handleResponse(response);
    } catch (e) {
      debugPrint('[ApiClient] POST $url failed: $e');
      rethrow;
    }
  }

  /// Perform a PUT request
  Future<dynamic> put(
    String url, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    debugPrint('[ApiClient] PUT $url (auth: $auth)');
    final headers = auth ? await _authHeaders() : _baseHeaders();
    try {
      final response = await _client
          .put(
            Uri.parse(url),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: _timeoutSeconds));
      return _handleResponse(response);
    } catch (e) {
      debugPrint('[ApiClient] PUT $url failed: $e');
      rethrow;
    }
  }

  /// Upload a single file with multipart/form-data.
  Future<dynamic> uploadFile(
    String url, {
    required String fieldName,
    required String filePath,
    bool auth = true,
  }) async {
    debugPrint('[ApiClient] UPLOAD $url (auth: $auth)');
    final headers = auth ? await _authHeaders() : _baseHeaders();
    headers.remove('Content-Type');

    try {
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers.addAll(headers);
      request.files.add(
        await http.MultipartFile.fromPath(
          fieldName,
          filePath,
          contentType: _contentTypeForPath(filePath),
        ),
      );

      final streamedResponse = await _client
          .send(request)
          .timeout(const Duration(seconds: _timeoutSeconds));
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('[ApiClient] UPLOAD $url failed: $e');
      rethrow;
    }
  }

  /// Perform a DELETE request
  Future<dynamic> delete(String url, {bool auth = true}) async {
    debugPrint('[ApiClient] DELETE $url (auth: $auth)');
    final headers = auth ? await _authHeaders() : _baseHeaders();
    try {
      final response = await _client
          .delete(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: _timeoutSeconds));
      return _handleResponse(response);
    } catch (e) {
      debugPrint('[ApiClient] DELETE $url failed: $e');
      rethrow;
    }
  }

  /// Check connectivity to various service health endpoints
  Future<void> checkHealth() async {
    debugPrint('[ApiClient] Starting health check...');
    final baseUrl = urlWithoutTrailingSlash(ApiConfig.baseUrl);
    final services = {
      'Gateway': '$baseUrl/openapi.json',
      'Auth': '$baseUrl/auth/health',
      'Journal': '$baseUrl/journal/health',
      'User': '$baseUrl/user/health',
      'Chat': '$baseUrl/chat/health',
      'Quest': '$baseUrl/challenge/health',
      'Coach': '$baseUrl/coach/health',
      'Meditation': '$baseUrl/meditation/health',
      'Notifications': '$baseUrl/notifications/health',
    };

    for (var entry in services.entries) {
      try {
        // Use the internal get method to benefit from logging, but disable auth
        await get(entry.value, auth: false);
        debugPrint('[ApiClient] ✅ ${entry.key} is UP');
      } catch (e) {
        debugPrint('[ApiClient] ❌ ${entry.key} is DOWN (or unreachable)');
      }
    }
  }

  String urlWithoutTrailingSlash(String url) {
    if (url.endsWith('/')) {
      return url.substring(0, url.length - 1);
    }
    return url;
  }

  MediaType _contentTypeForPath(String filePath) {
    final path = filePath.toLowerCase();
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    if (path.endsWith('.png')) {
      return MediaType('image', 'png');
    }
    if (path.endsWith('.webp')) {
      return MediaType('image', 'webp');
    }
    if (path.endsWith('.gif')) {
      return MediaType('image', 'gif');
    }
    return MediaType('application', 'octet-stream');
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
