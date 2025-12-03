import 'package:flutter/foundation.dart';

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
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
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
    final now = DateTime.now();
    _entries = [
      JournalEntry(
        id: '1',
        title: 'Premier jour',
        content: 'Aujourd\'hui a été une journée incroyable. J\'ai commencé à utiliser cette application et je me sens déjà plus serein.',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      JournalEntry(
        id: '2',
        title: 'Réflexion du soir',
        content: 'Je me sens un peu anxieux ce soir. Beaucoup de choses dans ma tête.',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      JournalEntry(
        id: '3',
        content: 'Une journée calme et reposante. J\'ai pris le temps de méditer.',
        createdAt: now,
        updatedAt: now,
      ),
    ];
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
