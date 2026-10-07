import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../network/api_exception.dart';

/// Bounded, content-free diagnostics. A host can attach a reporting sink;
/// records contain event/category only, never payloads, tokens or user IDs.
abstract final class AppDiagnostics {
  static final Queue<({String event, String category})> _events = Queue();
  static void Function(String event, String category)? sink;
  static List<({String event, String category})> get events =>
      List.unmodifiable(_events);
  static void record(String event, Object error) {
    final category = error is ApiException
        ? error.kind.name
        : error.runtimeType.toString();
    if (_events.length == 100) _events.removeFirst();
    _events.add((event: event, category: category));
    sink?.call(event, category);
    if (kDebugMode) debugPrint('[Elyrii] $event ($category)');
  }
}
