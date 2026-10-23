import '../../../../core/network/json_response.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/storage/content_cipher.dart';
import '../../../../core/diagnostics/app_diagnostics.dart';
import '../models/journal_entry_model.dart';
import 'journal_store.dart';

class JournalRepository {
  final ApiClient _client;
  final JournalStore store;
  String? storageWarning;
  static const pageSize = 100;
  Map<String, dynamic>? _cursor;
  int _offset = 0;
  DateTime? _startDate;
  DateTime? _endDate;
  int _pageVersion = 0;
  bool newestFirst = true;
  bool isPaginated = false;
  bool _offline = false;
  int? totalCount;
  bool get hasMore => _offline ? _offset < (totalCount ?? 0) : _cursor != null;
  void resetPagination() {
    _pageVersion++;
    _cursor = null;
    _offset = 0;
    totalCount = null;
    isPaginated = false;
    _offline = false;
  }

  Future<void> _cacheCommitted(Future<void> Function() write) async {
    storageWarning = null;
    try {
      await write();
    } catch (error) {
      // The server already committed. A failed local copy must never turn
      // that acknowledgement into a retryable remote failure.
      storageWarning =
          'Enregistrée sur le serveur. La copie hors ligne est indisponible.';
      AppDiagnostics.record('journal_local_copy_failed', error);
    }
  }

  JournalRepository({
    required ApiClient client,
    SharedPreferences? prefs,
    JournalStore? store,
  }) : _client = client,
       store = store ?? JournalStore(cipher: ContentCipher(client.storage));
  Future<String?> get currentOwner => _client.currentUserId;
  Future<List<JournalEntryModel>> getCachedEntries({String? owner}) async {
    owner ??= await currentOwner;
    if (owner == null || owner.isEmpty) return const [];
    return store.read(owner, limit: pageSize, newestFirst: newestFirst);
  }

  Future<bool> hasSnapshot(String owner) => store.hasSnapshot(owner);
  Future<List<JournalEntryModel>> getEntries({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    resetPagination();
    _startDate = startDate;
    _endDate = endDate;
    return _getPage(startDate: startDate, endDate: endDate);
  }

  Future<List<JournalEntryModel>> getMoreEntries() =>
      _getPage(more: true, startDate: _startDate, endDate: _endDate);
  Future<List<JournalEntryModel>> _getPage({
    DateTime? startDate,
    DateTime? endDate,
    bool more = false,
  }) async {
    final context = _client.sessionGeneration;
    final version = _pageVersion;
    final owner = await currentOwner;
    if (owner != null) await store.hasSnapshot(owner);
    final revision = owner == null ? 0 : store.revision(owner);
    try {
      _client.ensureSession(context);
      if (_offline && more) {
        throw const ApiException(
          statusCode: 0,
          message: 'Hors connexion',
          kind: ApiFailureKind.offline,
        );
      }
      final response = await _client.get(
        ApiConfig.journalUrl,
        queryParams: {
          'limit': '$pageSize',
          'order': newestFirst ? 'desc' : 'asc',
          if (startDate != null)
            'startDate': startDate.toUtc().toIso8601String(),
          if (endDate != null) 'endDate': endDate.toUtc().toIso8601String(),
          if (more && _cursor != null)
            'cursorDate': _cursor!['createdAt'] as String,
          if (more && _cursor != null) 'cursorId': _cursor!['id'] as String,
        },
      );
      final paged = response is Map && response['entries'] is List;
      final entries = decodeListResponse(
        paged ? response['entries'] : response,
        JournalEntryModel.fromJson,
      );
      if (owner != null && startDate == null && endDate == null) {
        await _cacheCommitted(
          () => paged
              ? store.mergePage(owner, entries, expectedRevision: revision)
              : store.replace(owner, entries, expectedRevision: revision),
        );
      }
      if (version == _pageVersion &&
          context == _client.sessionGeneration &&
          (owner == null || store.revision(owner) == revision)) {
        _offline = false;
        isPaginated = paged;
        _cursor = paged && response['nextCursor'] is Map
            ? Map<String, dynamic>.from(response['nextCursor'] as Map)
            : null;
        totalCount = paged ? response['totalCount'] as int? : entries.length;
        _offset += entries.length;
      }
      if (owner != null && store.revision(owner) != revision) {
        return await store.read(
          owner,
          limit: pageSize,
          newestFirst: newestFirst,
          startDate: startDate,
          endDate: endDate,
        );
      }
      return entries;
    } catch (error) {
      if (error is! ApiException ||
          !error.canUseOfflineData ||
          context != _client.sessionGeneration ||
          owner == null ||
          owner.isEmpty ||
          !await store.hasSnapshot(owner)) {
        rethrow;
      }
      final entries = await store.read(
        owner,
        limit: pageSize,
        offset: more ? _offset : 0,
        newestFirst: newestFirst,
        startDate: startDate,
        endDate: endDate,
      );
      if (version == _pageVersion && store.revision(owner) == revision) {
        _offline = true;
        isPaginated = true;
        totalCount = await store.count(
          owner,
          startDate: startDate,
          endDate: endDate,
        );
        _offset += entries.length;
      }
      return entries;
    }
  }

  Future<JournalEntryModel> getEntryById(String id) async => decodeResponse(
    await _client.get(ApiConfig.journalEntryUrl(id)),
    JournalEntryModel.fromJson,
  );
  Future<JournalEntryModel> createEntry({
    required String title,
    String? content,
    String? mood,
    List<String>? tags,
    String? clientRequestId,
  }) async {
    final context = _client.sessionGeneration;
    final owner = await currentOwner;
    if (owner != null) await store.hasSnapshot(owner);
    _client.ensureSession(context);
    final response = await _client.post(
      ApiConfig.journalUrl,
      body: {
        'title': title,
        'content': content,
        'mood': mood,
        'tags': tags,
        'clientRequestId': ?clientRequestId,
      },
    );
    final entry = decodeResponse(
      response,
      (json) =>
          decodeResponse(json['body'] ?? json, JournalEntryModel.fromJson),
    );
    if (owner != null) await _cacheCommitted(() => store.upsert(owner, entry));
    return entry;
  }

  Future<JournalEntryModel> updateEntry({
    required String id,
    String? title,
    String? content,
    String? mood,
  }) async {
    final context = _client.sessionGeneration;
    final owner = await currentOwner;
    if (owner != null) await store.hasSnapshot(owner);
    _client.ensureSession(context);
    final response = await _client.put(
      ApiConfig.journalEntryUrl(id),
      body: {'title': ?title, 'content': ?content, 'mood': ?mood},
    );
    final entry = decodeResponse(
      response,
      (json) =>
          decodeResponse(json['body'] ?? json, JournalEntryModel.fromJson),
    );
    if (owner != null) await _cacheCommitted(() => store.upsert(owner, entry));
    return entry;
  }

  Future<void> deleteEntry(String id) async {
    final context = _client.sessionGeneration;
    final owner = await currentOwner;
    if (owner != null) await store.hasSnapshot(owner);
    _client.ensureSession(context);
    await _client.delete(ApiConfig.journalEntryUrl(id));
    if (owner != null) await _cacheCommitted(() => store.delete(owner, id));
  }
}
