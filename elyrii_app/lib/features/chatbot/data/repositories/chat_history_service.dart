import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../entities/chat_session.dart';

/// Stockage local de l'historique des conversations (SharedPreferences,
/// JSON sérialisé). Fonne 100 % hors-ligne : les conversations survivent
/// au redémarrage de l'app même sans backend. Une migration vers le
/// backend remplacera seulement cette classe, pas les appelants.
abstract final class ChatHistoryService {
  static const _storageKey = 'chat_history_v1';

  /// Charge toutes les sessions, triées de la plus récente à la plus ancienne.
  static Future<List<ChatSession>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List;
      final sessions = decoded
          .whereType<Map<String, dynamic>>()
          .map(ChatSession.fromJson)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return sessions;
    } catch (_) {
      // Historique corrompu : repartir à vide plutôt que crasher.
      return const [];
    }
  }

  /// Persiste toute la liste (déjà triée par l'appelant).
  static Future<void> saveAll(List<ChatSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(sessions.map((s) => s.toJson()).toList()),
    );
  }

  /// Efface tout l'historique persisté.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
