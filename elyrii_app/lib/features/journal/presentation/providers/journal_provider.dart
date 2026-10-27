import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/models/journal_entry_model.dart';
import '../../data/repositories/journal_repository.dart';

/// Kept for backward compatibility — re-exports the model under old name
typedef JournalEntry = JournalEntryModel;

/// Provider managing journal state.
class JournalProvider extends ChangeNotifier {
  final JournalRepository _repository;
  final bool _ownsRepository;

  List<JournalEntryModel> _entries = [];
  List<JournalEntryModel> _sortedEntries = const [];
  bool _isLoading = false;
  String? _error;

  List<JournalEntryModel> get entries => _sortedEntries;
  bool get isLoading => _isLoading;
  String? get error => _error;

  JournalProvider({JournalRepository? repository, ApiClient? client})
    : assert(
        repository != null || client != null,
        'repository or client must be provided',
      ),
      _repository = repository ?? JournalRepository(client: client!),
      _ownsRepository = repository == null;

  /// Load entries from the backend
  final Map<(DateTime?, DateTime?), Future<void>> _loads = {};
  int _loadVersion = 0;
  int _mutationVersion = 0;
  bool _loadingMore = false;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _repository.hasMore;
  int? get totalCount => _repository.totalCount;
  int _sessionVersion = 0;
  String? _owner;
  String? get owner => _owner;
  String? get storageWarning => _repository.storageWarning;
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  void onUserChanged(String? owner) {
    _owner = owner;
    resetSession();
  }

  Future<Map<String, dynamic>?> readDraft(String key) async {
    final owner = _owner ?? await _repository.currentOwner;
    return owner == null ? null : _repository.store.readDraft(owner, key);
  }

  Future<void> saveDraft(String key, Map<String, dynamic> value) async {
    final revision = _sessionVersion;
    final owner = _owner ?? await _repository.currentOwner;
    if (owner == null || _disposed || revision != _sessionVersion) return;
    await _repository.store.saveDraft(owner, key, value);
  }

  Future<void> deleteDraft(String key) async {
    final owner = _owner ?? await _repository.currentOwner;
    if (owner != null) await _repository.store.deleteDraft(owner, key);
  }

  Future<List<Map<String, dynamic>>> exportDrafts() async {
    final session = _sessionVersion;
    final owner = _owner ?? await _repository.currentOwner;
    if (owner == null || session != _sessionVersion) return const [];
    final drafts = await _repository.store.exportDrafts(owner);
    return session == _sessionVersion ? drafts : const [];
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionVersion++;
    _loadVersion++;
    if (_ownsRepository) unawaited(_repository.store.close());
    super.dispose();
  }

  /// Logout also invalidates requests still using the previous credentials.
  void resetSession() {
    _sessionVersion++;
    _loadVersion++;
    _loads.clear();
    _entries = [];
    _sortedEntries = const [];
    _isLoading = false;
    _error = null;
    _repository.storageWarning = null;
    _repository.resetPagination();
    _loadingMore = false;
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

  Future<void> loadMore() async {
    if (_isLoading || _loadingMore || !hasMore) return;
    final session = _sessionVersion;
    final mutation = _mutationVersion;
    final load = _loadVersion;
    _loadingMore = true;
    _error = null;
    notifyListeners();
    try {
      final page = await _repository.getMoreEntries();
      if (session != _sessionVersion ||
          mutation != _mutationVersion ||
          load != _loadVersion) {
        return;
      }
      final known = _entries.map((entry) => entry.id).toSet();
      _entries.addAll(page.where((entry) => !known.contains(entry.id)));
      _updateSortedEntries();
    } catch (e) {
      if (session == _sessionVersion) {
        _error = e is ApiException
            ? e.message
            : 'Impossible de charger les notes suivantes.';
      }
    } finally {
      if (session == _sessionVersion) {
        _loadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadEntries({DateTime? startDate, DateTime? endDate}) async {
    final version = ++_loadVersion;
    final mutation = _mutationVersion;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final pending = _repository.getEntries(
        startDate: startDate,
        endDate: endDate,
      );
      pending.ignore();
      final cached = await _repository.getCachedEntries();
      if (version != _loadVersion || mutation != _mutationVersion) return;
      _entries = cached
          .where(
            (entry) =>
                (startDate == null || !entry.createdAt.isBefore(startDate)) &&
                (endDate == null || !entry.createdAt.isAfter(endDate)),
          )
          .toList();
      _updateSortedEntries();
      if (cached.isNotEmpty) _isLoading = false;
      notifyListeners();
      final entries = await pending;
      if (version != _loadVersion || mutation != _mutationVersion) return;
      // Decoded pages are unmodifiable; creation, edits and deletion patch
      // this list in place.
      _entries = List.of(entries);
      _updateSortedEntries();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (version != _loadVersion || mutation != _mutationVersion) return;
      _error = e is ApiException
          ? e.message
          : 'Impossible de charger les notes. Réessaie.';
    } finally {
      if (version == _loadVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _updateSortedEntries() {
    final sorted = List<JournalEntryModel>.from(_entries);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _sortedEntries = List.unmodifiable(sorted);
  }

  Future<JournalEntryModel?> createEntry({
    String? clientRequestId,
    String? title,
    required String content,
    String? mood,
  }) async {
    final session = _sessionVersion;
    _mutationVersion++;
    try {
      final entry = await _repository.createEntry(
        clientRequestId: clientRequestId,
        title: title == null || title.trim().isEmpty ? 'Sans titre' : title,
        content: content,
        mood: mood,
      );
      if (session != _sessionVersion) return null;
      _mutationVersion++;
      _entries.removeWhere((existing) => existing.id == entry.id);
      _entries.add(entry);
      _error = null;
      _updateSortedEntries();
      notifyListeners();
      return entry;
    } catch (e) {
      if (session != _sessionVersion) return null;
      _error = e is ApiException
          ? e.message
          : 'Impossible d’enregistrer la note. Réessaie.';
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
    _mutationVersion++;
    try {
      final updated = await _repository.updateEntry(
        id: id,
        title: title,
        content: content,
        mood: mood,
      );
      if (session != _sessionVersion) return false;
      _mutationVersion++;
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
      _error = e is ApiException
          ? e.message
          : 'Impossible de modifier la note. Réessaie.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteEntry(String id) async {
    final session = _sessionVersion;
    _mutationVersion++;
    try {
      await _repository.deleteEntry(id);
      if (session != _sessionVersion) return false;
      _mutationVersion++;
      _error = null;
      _entries.removeWhere((e) => e.id == id);
      _updateSortedEntries();
      notifyListeners();
      return true;
    } catch (e) {
      if (session != _sessionVersion) return false;
      _error = e is ApiException
          ? e.message
          : 'Impossible de supprimer la note. Réessaie.';
      notifyListeners();
      return false;
    }
  }
}
