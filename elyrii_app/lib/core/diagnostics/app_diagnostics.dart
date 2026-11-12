import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_exception.dart';

/// Bounded technical events, retained for seven days on this device.
/// No exception text, stack traces, payloads, tokens, user IDs or automatic upload.
abstract final class AppDiagnostics {
  static const _key = 'technical_diagnostics_v1';
  static final Queue<({String event, String category})> _events = Queue();
  static final Queue<Map<String, String>> _stored = Queue();
  static Future<void> _writes = Future.value();
  static SharedPreferences? _preferences;
  static void Function(String event, String category)? sink;
  static List<({String event, String category})> get events =>
      List.unmodifiable(_events);
  static Future<void> initialize() async {
    await _writes;
    final prefs = _preferences = await SharedPreferences.getInstance();
    _stored.clear();
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    try {
      final history = jsonDecode(prefs.getString(_key) ?? '[]') as List;
      for (final row in history) {
        final item = Map<String, String>.from(row as Map);
        if (!DateTime.parse(item['at']!).isBefore(cutoff) &&
            _stored.length < 100) {
          _stored.add(item);
        }
      }
    } catch (_) {
      await prefs.remove(_key);
    }
    _persist();
  }

  static void _prune() {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    _stored.removeWhere((item) => DateTime.parse(item['at']!).isBefore(cutoff));
  }

  static void _persist() {
    final snapshot = jsonEncode(_stored.toList());
    _writes = _writes
        .then((_) async {
          final prefs = _preferences;
          if (prefs != null) await prefs.setString(_key, snapshot);
        })
        .catchError((Object _) {});
  }

  static void record(String event, Object error) {
    _prune();
    final category = error is ApiException
        ? error.kind.name
        : error.runtimeType.toString();
    if (_events.length == 100) _events.removeFirst();
    _events.add((event: event, category: category));
    if (_stored.length == 100) _stored.removeFirst();
    _stored.add({
      'event': event,
      'category': category,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    _persist();
    try {
      sink?.call(event, category);
    } catch (_) {}
    if (kDebugMode) debugPrint('[Elyrii] $event ($category)');
  }

  static Future<Map<String, dynamic>> export() async {
    _prune();
    _persist();
    await _writes;
    final info = await PackageInfo.fromPlatform();
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return {
      'schemaVersion': 1,
      'version': info.version,
      'build': info.buildNumber,
      'events': _stored
          .where((item) => DateTime.parse(item['at']!).isAfter(cutoff))
          .toList(),
    };
  }
}
