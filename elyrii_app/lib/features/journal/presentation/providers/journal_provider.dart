import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/journal_entry_model.dart';
import '../../data/repositories/journal_repository.dart';

/// Kept for backward compatibility — re-exports the model under old name
typedef JournalEntry = JournalEntryModel;

/// Provider pour gérer l'état du journal
class JournalProvider extends ChangeNotifier {
  final JournalRepository _repository;

  List<JournalEntryModel> _entries = [];
  List<JournalEntryModel> _sortedEntries = const [];
  bool _sortNewest = true;
  bool _isLoading = false;
  String? _error;

  List<JournalEntryModel> get entries => _sortedEntries;
  bool get sortNewest => _sortNewest;
  bool get isLoading => _isLoading;
  String? get error => _error;

  JournalProvider({JournalRepository? repository, ApiClient? client})
    : assert(
        repository != null || client != null,
        'repository or client must be provided',
      ),
      _repository = repository ?? JournalRepository(client: client!);

  /// Load entries from the backend
  Future<void> loadEntries({DateTime? startDate, DateTime? endDate}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _entries = await _repository.getEntries(
        startDate: startDate,
        endDate: endDate,
      );
      _updateSortedEntries();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void _updateSortedEntries() {
    final sorted = List<JournalEntryModel>.from(_entries);
    sorted.sort(
      (a, b) => _sortNewest
          ? b.createdAt.compareTo(a.createdAt)
          : a.createdAt.compareTo(b.createdAt),
    );
    _sortedEntries = List.unmodifiable(sorted);
  }

  Future<JournalEntryModel?> createEntry({
    String? title,
    required String content,
    String? mood,
  }) async {
    try {
      final entry = await _repository.createEntry(
        title: title ?? 'Sans titre',
        content: content,
        mood: mood,
      );
      _entries.add(entry);
      _updateSortedEntries();
      notifyListeners();
      return entry;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> updateEntry(
    String id, {
    String? title,
    String? content,
    String? mood,
  }) async {
    try {
      final updated = await _repository.updateEntry(
        id: id,
        title: title,
        content: content,
        mood: mood,
      );
      final index = _entries.indexWhere((e) => e.id == id);
      if (index != -1) {
        _entries[index] = updated;
        _updateSortedEntries();
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteEntry(String id) async {
    try {
      await _repository.deleteEntry(id);
      _entries.removeWhere((e) => e.id == id);
      _updateSortedEntries();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void toggleSort() {
    _sortNewest = !_sortNewest;
    _updateSortedEntries();
    notifyListeners();
  }
}
