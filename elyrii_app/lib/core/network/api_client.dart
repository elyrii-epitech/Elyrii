import 'dart:async';
import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/api_config.dart';
import '../services/secure_storage_service.dart';
import 'api_exception.dart';
import 'transport_failure.dart';

/// One transport boundary for errors, full-response deadlines, cancellation
/// and shared concurrent GETs. Mutations are never retried automatically.
class ApiClient {
  final http.Client _client;
  final SecureStorageService _storage;
  final Duration timeout;
  final Map<(String, bool, int), Future<dynamic>> _reads = {};
  final Map<Completer<void>, bool> _active = {};
  int _generation = 0;
  bool _disposed = false;
  void Function(String? owner)? onUnauthorized;
  Future<String?> get currentUserId => _storage.getUserId();
  SecureStorageService get storage => _storage;
  int get sessionGeneration => _generation;
  void ensureSession(int generation) {
    if (_disposed || generation != _generation) {
      throw const ApiException(
        statusCode: 0,
        message: 'Session modifiée.',
        kind: ApiFailureKind.cancelled,
      );
    }
  }

  ApiClient({
    required this._storage,
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client();

  void invalidateSession() {
    _generation++;
    _reads.clear();
    for (final entry in _active.entries.toList()) {
      if (entry.value && !entry.key.isCompleted) entry.key.complete();
    }
  }

  Future<dynamic> get(
    String url, {
    bool auth = true,
    Map<String, String>? queryParams,
  }) {
    final uri = queryParams == null
        ? Uri.parse(url)
        : Uri.parse(url).replace(queryParameters: queryParams);
    final key = (uri.toString(), auth, _generation);
    final existing = _reads[key];
    if (existing != null) return existing;
    late final Future<dynamic> request;
    request = _request('GET', uri, auth: auth).whenComplete(() {
      if (identical(_reads[key], request)) _reads.remove(key);
    });
    return _reads[key] = request;
  }

  Future<dynamic> postWithToken(String url, String token) =>
      _request('POST', Uri.parse(url), auth: false, bearerToken: token);
  Future<dynamic> post(
    String url, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) => _request('POST', Uri.parse(url), body: body, auth: auth);
  Future<dynamic> put(
    String url, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) => _request('PUT', Uri.parse(url), body: body, auth: auth);
  Future<dynamic> delete(
    String url, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) => _request('DELETE', Uri.parse(url), body: body, auth: auth);
  Future<dynamic> uploadFile(
    String url, {
    required String fieldName,
    required String filePath,
    bool auth = true,
  }) =>
      uploadXFile(url, fieldName: fieldName, file: XFile(filePath), auth: auth);
  Future<dynamic> uploadXFile(
    String url, {
    required String fieldName,
    required XFile file,
    bool auth = true,
  }) => _request(
    'POST',
    Uri.parse(url),
    auth: auth,
    file: file,
    fieldName: fieldName,
  );

  Future<dynamic> _request(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
    required bool auth,
    XFile? file,
    String? fieldName,
    String? bearerToken,
  }) =>
      _performRequest(
        method,
        uri,
        body: body,
        auth: auth,
        file: file,
        fieldName: fieldName,
        bearerToken: bearerToken,
      ).timeout(
        timeout,
        onTimeout: () => throw const ApiException(
          statusCode: 0,
          message: 'Le service met trop de temps à répondre.',
          kind: ApiFailureKind.timeout,
        ),
      );

  Future<dynamic> _performRequest(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
    required bool auth,
    XFile? file,
    String? fieldName,
    String? bearerToken,
  }) async {
    if (_disposed) {
      throw const ApiException(
        statusCode: 0,
        message: 'Client fermé.',
        kind: ApiFailureKind.cancelled,
      );
    }
    final generation = _generation;
    final abort = Completer<void>();
    _active[abort] = auth;
    var timedOut = false;
    final timer = Timer(timeout, () {
      timedOut = true;
      if (!abort.isCompleted) abort.complete();
    });
    String? owner;
    try {
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (bearerToken?.isNotEmpty ?? false) {
        headers['Authorization'] = 'Bearer $bearerToken';
      }
      if (auth) {
        owner = await currentUserId;
        final token = await _storage.getAccessToken();
        if (token?.isNotEmpty ?? false) {
          headers['Authorization'] = 'Bearer $token';
        }
      }
      if (abort.isCompleted || (auth && generation != _generation)) {
        throw const ApiException(
          statusCode: 0,
          message: 'Opération annulée.',
          kind: ApiFailureKind.cancelled,
        );
      }
      final http.BaseRequest request;
      if (file != null) {
        headers.remove('Content-Type');
        final multipart = http.AbortableMultipartRequest(
          method,
          uri,
          abortTrigger: abort.future,
        );
        multipart.files.add(
          http.MultipartFile.fromBytes(
            fieldName!,
            await file.readAsBytes(),
            filename: file.name,
            contentType: _contentTypeForPath(file.name),
          ),
        );
        request = multipart;
      } else {
        final regular = http.AbortableRequest(
          method,
          uri,
          abortTrigger: abort.future,
        );
        if (body != null) regular.body = jsonEncode(body);
        request = regular;
      }
      if (auth) ensureSession(generation);
      if (abort.isCompleted) {
        throw ApiException(
          statusCode: 0,
          message: timedOut
              ? 'Le service met trop de temps à répondre.'
              : 'Opération annulée.',
          kind: timedOut ? ApiFailureKind.timeout : ApiFailureKind.cancelled,
        );
      }
      request.headers.addAll(headers);
      final response =
          await (() async => http.Response.fromStream(
            await _client.send(request),
          ))().timeout(
            timeout,
            onTimeout: () {
              timedOut = true;
              if (!abort.isCompleted) abort.complete();
              throw const ApiException(
                statusCode: 0,
                message: 'Le service met trop de temps à répondre.',
                kind: ApiFailureKind.timeout,
              );
            },
          );
      if (auth && generation != _generation) {
        throw const ApiException(
          statusCode: 0,
          message: 'Session modifiée.',
          kind: ApiFailureKind.cancelled,
        );
      }
      if (response.statusCode == 401 && auth) onUnauthorized?.call(owner);
      return _handleResponse(response);
    } on http.RequestAbortedException {
      throw ApiException(
        statusCode: 0,
        message: timedOut
            ? 'Le service met trop de temps à répondre.'
            : 'Opération annulée.',
        kind: timedOut ? ApiFailureKind.timeout : ApiFailureKind.cancelled,
      );
    } on http.ClientException {
      throw const ApiException(
        statusCode: 0,
        message: 'Connexion au service indisponible.',
        kind: ApiFailureKind.offline,
      );
    } on TimeoutException {
      throw const ApiException(
        statusCode: 0,
        message: 'Le service met trop de temps à répondre.',
        kind: ApiFailureKind.timeout,
      );
    } catch (error) {
      if (isSocketFailure(error)) {
        throw const ApiException(
          statusCode: 0,
          message: 'Connexion au service indisponible.',
          kind: ApiFailureKind.offline,
        );
      }
      rethrow;
    } finally {
      timer.cancel();
      _active.remove(abort);
    }
  }

  dynamic _handleResponse(http.Response response) {
    Object? body;
    try {
      body = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } catch (_) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        throw const ApiException(
          statusCode: 200,
          message: 'Réponse du service invalide.',
          kind: ApiFailureKind.protocol,
        );
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    final map = body is Map ? body : const <String, dynamic>{};
    final message = map['message'] ?? map['error'];
    throw ApiException(
      statusCode: response.statusCode,
      message: message is String ? message : 'Le service a refusé la demande.',
      body: body,
    );
  }

  MediaType _contentTypeForPath(String value) {
    final name = value.toLowerCase();
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    if (name.endsWith('.png')) return MediaType('image', 'png');
    if (name.endsWith('.webp')) return MediaType('image', 'webp');
    if (name.endsWith('.gif')) return MediaType('image', 'gif');
    return MediaType('application', 'octet-stream');
  }

  String urlWithoutTrailingSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  Future<void> checkHealth() async {
    await get(
      '${urlWithoutTrailingSlash(ApiConfig.baseUrl)}/openapi.json',
      auth: false,
    );
  }

  void dispose() {
    _disposed = true;
    invalidateSession();
    for (final abort in _active.keys.toList()) {
      if (!abort.isCompleted) abort.complete();
    }
    _client.close();
  }
}
