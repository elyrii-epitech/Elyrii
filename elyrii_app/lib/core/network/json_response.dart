import 'api_exception.dart';

/// Decode external JSON at repository boundaries, preserving transport errors.
T decodeResponse<T>(Object? data, T Function(Map<String, dynamic>) decode) {
  try {
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON object');
    }
    return decode(data);
  } on FormatException {
    throw const ApiException(
      statusCode: 0,
      message: 'La réponse du service est invalide.',
      kind: ApiFailureKind.protocol,
    );
  } on TypeError {
    throw const ApiException(
      statusCode: 0,
      message: 'La réponse du service est invalide.',
      kind: ApiFailureKind.protocol,
    );
  }
}

/// Accept a JSON list or a data envelope, and validate each element.
List<T> decodeListResponse<T>(
  Object? response,
  T Function(Map<String, dynamic>) decode,
) {
  final data = response is List
      ? response
      : response is Map<String, dynamic>
      ? response['data']
      : null;
  if (data is! List) {
    throw const ApiException(
      statusCode: 0,
      message: 'La réponse du service est invalide.',
      kind: ApiFailureKind.protocol,
    );
  }
  return List.unmodifiable(data.map((item) => decodeResponse(item, decode)));
}
