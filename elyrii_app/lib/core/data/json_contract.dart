/// Validate fields that identify a persisted resource; tolerate unknown options.
String requiredJsonString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing or invalid $field');
  }
  return value;
}

DateTime requiredJsonDate(Object? value, String field) {
  if (value is String) {
    final result = DateTime.tryParse(value);
    if (result != null) return result;
  }
  throw FormatException('Missing or invalid $field');
}

/// Recursively detach JSON-shaped snapshots from mutable caller collections.
dynamic freezeJson(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable({
      for (final entry in value.entries)
        entry.key as String: freezeJson(entry.value),
    });
  }
  if (value is List) return List<dynamic>.unmodifiable(value.map(freezeJson));
  return value;
}
