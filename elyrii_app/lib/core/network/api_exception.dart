enum ApiFailureKind {
  unauthorized,
  forbidden,
  validation,
  server,
  offline,
  timeout,
  cancelled,
  protocol,
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Object? body;
  final ApiFailureKind? _kind;
  const ApiException({
    required this.statusCode,
    required this.message,
    this.body,
    this._kind,
  });
  ApiFailureKind get kind =>
      _kind ??
      (statusCode == 401
          ? ApiFailureKind.unauthorized
          : statusCode == 403
          ? ApiFailureKind.forbidden
          : statusCode >= 500
          ? ApiFailureKind.server
          : statusCode == 0
          ? ApiFailureKind.offline
          : ApiFailureKind.validation);
  bool get isUnauthorized => kind == ApiFailureKind.unauthorized;
  bool get isForbidden => kind == ApiFailureKind.forbidden;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => kind == ApiFailureKind.server;
  bool get canUseOfflineData =>
      kind == ApiFailureKind.offline ||
      kind == ApiFailureKind.timeout ||
      kind == ApiFailureKind.server;
  @override
  String toString() => message;
}
