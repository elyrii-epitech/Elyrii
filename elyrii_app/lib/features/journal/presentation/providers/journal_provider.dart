import 'package:flutter/foundation.dart';

/// Modèle de données pour une entrée du journal intime
class JournalEntry {
  final String id;
  final String? title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;

  const JournalEntry({
    required this.id,
    this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
  });

  JournalEntry copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
    );
  }
}



/// Provider pour gérer l'état du journal
class JournalProvider extends ChangeNotifier {
  List<JournalEntry> _entries = [];
  String _searchQuery = '';
  bool _sortNewest = true;

  List<JournalEntry> get entries => _getFilteredEntries();
  String get searchQuery => _searchQuery;
  bool get sortNewest => _sortNewest;

  JournalProvider() {
    _loadMockData();
  }

  /// Charge des données de test
  void _loadMockData() {
    final now = DateTime.now();
    _entries = [
      JournalEntry(
        id: '1',
        title: 'Premier jour',
        content:
            'Aujourd\'hui a été une journée incroyable. J\'ai commencé à utiliser cette application et je me sens déjà plus serein.',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      JournalEntry(
        id: '2',
        title: 'Réflexion du soir',
        content:
            'Je me sens un peu anxieux ce soir. Beaucoup de choses dans ma tête.',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      JournalEntry(
        id: '3',
        content:
            'Une journée calme et reposante. J\'ai pris le temps de méditer.',
        createdAt: now,
        updatedAt: now,
      ),
    ];
    notifyListeners();
  }

  /// Retourne les entrées filtrées et triées
  List<JournalEntry> _getFilteredEntries() {
    var filtered = List<JournalEntry>.from(_entries);

    // Filtrer par recherche
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((e) {
        final titleMatch =
            e.title?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                false;
        final contentMatch =
            e.content.toLowerCase().contains(_searchQuery.toLowerCase());
        return titleMatch || contentMatch;
      }).toList();
    }

    // Trier par date
    filtered.sort((a, b) {
      if (_sortNewest) {
        return b.createdAt.compareTo(a.createdAt);
      } else {
        return a.createdAt.compareTo(b.createdAt);
      }
    });

    return filtered;
  }

  /// Crée une nouvelle entrée
  void createEntry({
    String? title,
    required String content,
  }) {
    final now = DateTime.now();
    final entry = JournalEntry(
      id: now.millisecondsSinceEpoch.toString(),
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    _entries.add(entry);
    notifyListeners();
  }

  /// Met à jour une entrée existante
  void updateEntry(String id, {
    String? title,
    String? content,
  }) {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index != -1) {
      _entries[index] = _entries[index].copyWith(
        title: title,
        content: content,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  /// Supprime une entrée
  void deleteEntry(String id) {
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  /// Récupère une entrée par son ID
  JournalEntry? getEntry(String id) {
    try {
      return _entries.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }



  /// Met à jour la recherche
  void updateSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Change l'ordre de tri
  void toggleSort() {
    _sortNewest = !_sortNewest;
    notifyListeners();
  }

  /// Efface tous les filtres
  void clearFilters() {
    _searchQuery = '';
    notifyListeners();
  }
}
