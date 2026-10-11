import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../config/dev_session.dart';
import 'api_exception.dart';

/// Ephemeral, local HTTP contracts. Demo credentials must never reach transport.
class DemoApi {
  final _journal = <String, Map<String, dynamic>>{};
  final _sessions = <String, Map<String, dynamic>>{};
  final _profile = <String, dynamic>{
    'id': DevSession.userId,
    'email': DevSession.email,
    'firstName': DevSession.firstName,
  };
  final _settings = <String, dynamic>{
    'id': 'demo-settings',
    'userId': DevSession.userId,
    'themeMode': 'SYSTEM',
    'hapticsEnabled': true,
    'privacyMode': 'STANDARD',
    'language': 'fr',
  };
  Map<String, dynamic> _mascot = {};
  static bool accepts(String? token) {
    if (token == null || !token.endsWith('.demo')) return false;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map;
      return payload['sub'] == DevSession.userId;
    } catch (_) {
      return false;
    }
  }

  dynamic request(String method, Uri uri, Map<String, dynamic>? data) {
    final path = uri.path;
    final body = data ?? <String, dynamic>{};
    final now = DateTime.now().toUtc().toIso8601String();
    if (path == '/auth/logout' || path == '/user/account') {
      return {'message': 'Terminé en démonstration'};
    }
    if (path == '/user/me') {
      if (method == 'PUT') _profile.addAll(body);
      return Map.of(_profile);
    }
    if (path == '/user/settings') {
      if (method == 'PUT') _settings.addAll(body);
      return Map.of(_settings);
    }
    if (path == '/user/mascot') {
      if (method == 'PUT') _mascot = Map.of(body);
      return Map.of(_mascot);
    }
    if (path == '/user/avatar') {
      throw const ApiException(
        statusCode: 503,
        message: 'L’envoi de photo nécessite un compte réel.',
      );
    }
    if (path == '/user/mood' || path == '/user/mood/latest') {
      return {'moodType': body['moodType'], 'createdAt': now};
    }
    if (path == '/user/dashboard' || path == '/user/stats') {
      final stats = {
        'rangeDays': 30,
        'streak': DevSession.streakDays,
        'completedChallengesCount': DevSession.completedChallengeCount,
        'totalPoints': DevSession.totalPoints,
        'journalEntriesCount': _journal.length,
        'moodLogsCount': 7,
        'moodTrend7Days': [
          for (var i = 0; i < 7; i++)
            {
              'day': DateTime.now()
                  .subtract(Duration(days: 6 - i))
                  .toIso8601String()
                  .split('T')
                  .first,
              'count': 1,
            },
        ],
        'moodDistribution': [
          {'moodType': 'happy', 'count': 7},
        ],
        'activityTimeline': [
          {
            'day': now.split('T').first,
            'moodLogs': 1,
            'journalEntries': _journal.length,
          },
        ],
      };
      return path == '/user/stats'
          ? stats
          : {
              'stats': stats,
              'challenges': {'active': [], 'pending': []},
            };
    }
    if (path == '/user/export') {
      return {
        'schemaVersion': 1,
        'profile': Map.of(_profile),
        'settings': Map.of(_settings),
        'journal': _journal.values.toList(),
        'sessions': _sessions.values.toList(),
        'demo': true,
      };
    }
    if (path == '/journal') {
      if (method == 'GET') return _journal.values.toList();
      if (method == 'POST') {
        final requestId = body['clientRequestId'];
        for (final entry in _journal.values) {
          if (requestId != null && entry['clientRequestId'] == requestId) {
            return {'body': Map.of(entry)};
          }
        }
        final id = const Uuid().v4();
        final entry = {
          'id': id,
          'userId': DevSession.userId,
          ...body,
          'createdAt': now,
          'updatedAt': now,
        };
        _journal[id] = entry;
        return {'body': Map.of(entry)};
      }
    }
    if (path.startsWith('/journal/')) {
      final id = uri.pathSegments[1];
      final entry = _journal[id];
      if (entry == null) {
        throw const ApiException(
          statusCode: 404,
          message: 'Note introuvable en démonstration.',
        );
      }
      if (method == 'DELETE') {
        _journal.remove(id);
        return {'message': 'Supprimée'};
      }
      if (method == 'PUT') entry.addAll({...body, 'updatedAt': now});
      return {'body': Map.of(entry)};
    }
    if (path == '/meditation/catalog' || path.startsWith('/challenge/')) {
      return <dynamic>[];
    }
    if (path == '/coach/sessions' || path == '/meditation/sessions') {
      if (method == 'GET') {
        return _sessions.values
            .where((s) => s['service'] == uri.pathSegments[0])
            .toList();
      }
    }
    if (path == '/coach/sessions' || path == '/meditation/sessions/start') {
      final id = const Uuid().v4();
      final session = {
        'id': id,
        ...body,
        'service': uri.pathSegments[0],
        'status': 'STARTED',
        'createdAt': now,
        'startedAt': now,
        'response': 'Séance de démonstration locale.',
      };
      _sessions[id] = session;
      return Map.of(session);
    }
    if (path.startsWith('/meditation/sessions/') &&
        uri.pathSegments.length == 4) {
      final session = _sessions[uri.pathSegments[2]];
      if (session != null) {
        session.addAll({
          ...body,
          'status': path.endsWith('/complete') ? 'COMPLETED' : 'CANCELLED',
          'endedAt': now,
        });
        return Map.of(session);
      }
    }
    throw const ApiException(
      statusCode: 503,
      message: 'Cette action nécessite un compte réel.',
    );
  }
}
