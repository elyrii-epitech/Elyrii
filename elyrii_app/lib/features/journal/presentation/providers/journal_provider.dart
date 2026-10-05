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
  final Map<(DateTime?, DateTime?), Future<void>> _loads = {};
  int _loadVersion = 0;
  int _sessionVersion = 0;

  /// Logout also invalidates requests still using the previous credentials.
  void resetSession() {
    _sessionVersion++;
    _loadVersion++;
    _loads.clear();
    _entries = [];
    _sortedEntries = const [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> loadEntries({DateTime? startDate, DateTime? endDate}) {
    final key = (startDate, endDate);
    final existing = _loads[key];
    if (existing != null) return existing;
    late final Future<void> request;
    request = _loadEntries(startDate: startDate, endDate: endDate).whenComplete(
      () {
        if (identical(_loads[key], request)) _loads.remove(key);
      },
    );
    return _loads[key] = request;
  }

  Future<void> _loadEntries({DateTime? startDate, DateTime? endDate}) async {
    final version = ++_loadVersion;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final entries = await _repository.getEntries(
        startDate: startDate,
        endDate: endDate,
      );
      if (version != _loadVersion) return;
      _entries = entries;
      _updateSortedEntries();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (version != _loadVersion) return;
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
    final session = _sessionVersion;
    try {
      final entry = await _repository.createEntry(
        title: title ?? 'Sans titre',
        content: content,
        mood: mood,
      );
      if (session != _sessionVersion) return null;
      _entries.add(entry);
      _error = null;
      _updateSortedEntries();
      notifyListeners();
      return entry;
    } catch (e) {
      if (session != _sessionVersion) return null;
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateEntry(
    String id, {
    String? title,
    String? content,
    String? mood,
  }) async {
    final session = _sessionVersion;
    try {
      final updated = await _repository.updateEntry(
        id: id,
        title: title,
        content: content,
        mood: mood,
      );
      if (session != _sessionVersion) return false;
      final index = _entries.indexWhere((e) => e.id == id);
      _error = null;
      if (index != -1) {
        _entries[index] = updated;
        _updateSortedEntries();
      }
      notifyListeners();
      return true;
    } catch (e) {
      if (session != _sessionVersion) return false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteEntry(String id) async {
    final session = _sessionVersion;
    try {
      await _repository.deleteEntry(id);
      if (session != _sessionVersion) return;
      _entries.removeWhere((e) => e.id == id);
      _updateSortedEntries();
      notifyListeners();
    } catch (e) {
      if (session != _sessionVersion) return;
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
