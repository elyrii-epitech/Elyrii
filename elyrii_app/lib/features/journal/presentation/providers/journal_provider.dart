import 'package:flutter/foundation.dart';
import '../../data/mock_journal_entries.dart';

/// Modèle de données pour une entrée du journal
class JournalEntry {
  final String id;
  final String? title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  const JournalEntry({
    required this.id,
    this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  JournalEntry copyWith({
    String? id,
    Object? title = const _Sentinel(),
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      title: title == const _Sentinel() ? this.title : title as String?,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Classe sentinel pour différencier null explicite de l'absence de paramètre
class _Sentinel {
  const _Sentinel();
}

/// Provider pour gérer l'état du journal
class JournalProvider extends ChangeNotifier {
  List<JournalEntry> _entries = [];
  bool _sortNewest = true;

  List<JournalEntry> get entries => _getSortedEntries();
  bool get sortNewest => _sortNewest;

  JournalProvider() {
    _loadMockData();
  }

  void _loadMockData() {
    _entries = getMockJournalEntries();
    notifyListeners();
  }

  List<JournalEntry> _getSortedEntries() {
    final sorted = List<JournalEntry>.from(_entries);
    sorted.sort((a, b) => _sortNewest
        ? b.createdAt.compareTo(a.createdAt)
        : a.createdAt.compareTo(b.createdAt));
    return sorted;
  }

  void createEntry({String? title, required String content}) {
    final now = DateTime.now();
    _entries.add(JournalEntry(
      id: now.millisecondsSinceEpoch.toString(),
      title: title?.isNotEmpty == true ? title : null,
      content: content,
      createdAt: now,
      updatedAt: now,
    ));
    notifyListeners();
  }

  void updateEntry(String id, {String? title, String? content}) {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index != -1) {
      _entries[index] = _entries[index].copyWith(
        title: title?.isNotEmpty == true ? title : null,
        content: content,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  void deleteEntry(String id) {
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  void toggleSort() {
    _sortNewest = !_sortNewest;
    notifyListeners();
  }
}
