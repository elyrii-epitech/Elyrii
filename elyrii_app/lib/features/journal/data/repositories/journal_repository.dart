import '../../../../core/network/json_response.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/storage/content_cipher.dart';
import '../models/journal_entry_model.dart';
import 'journal_store.dart';

class JournalRepository {
  final ApiClient _client;
  final JournalStore store;
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
    return store.read(owner);
  }

  Future<bool> hasSnapshot(String owner) => store.hasSnapshot(owner);
  Future<List<JournalEntryModel>> getEntries({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final context = _client.sessionGeneration;
    final owner = await currentOwner;
    if (owner != null) await store.hasSnapshot(owner);
    final revision = owner == null ? 0 : store.revision(owner);
    try {
      _client.ensureSession(context);
      final response = await _client.get(
        ApiConfig.journalUrl,
        queryParams: {
          if (startDate != null) 'startDate': startDate.toIso8601String(),
          if (endDate != null) 'endDate': endDate.toIso8601String(),
        },
      );
      final entries = decodeListResponse(response, JournalEntryModel.fromJson);
      if (owner != null && startDate == null && endDate == null) {
        await store.replace(owner, entries, expectedRevision: revision);
      }
      return entries;
    } catch (e) {
      if (e is! ApiException ||
          !e.canUseOfflineData ||
          context != _client.sessionGeneration) {
        rethrow;
      }
      if (owner == null || owner.isEmpty || !await store.hasSnapshot(owner)) {
        rethrow;
      }
      return (await store.read(owner))
          .where(
            (entry) =>
                (startDate == null || !entry.createdAt.isBefore(startDate)) &&
                (endDate == null || !entry.createdAt.isAfter(endDate)),
          )
          .toList();
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
  }) async {
    final context = _client.sessionGeneration;
    final owner = await currentOwner;
    if (owner != null) await store.hasSnapshot(owner);
    _client.ensureSession(context);
    final response = await _client.post(
      ApiConfig.journalUrl,
      body: {'title': title, 'content': content, 'mood': mood, 'tags': tags},
    );
    final entry = decodeResponse(
      response,
      (json) =>
          decodeResponse(json['body'] ?? json, JournalEntryModel.fromJson),
    );
    if (owner != null) await store.upsert(owner, entry);
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
    if (owner != null) await store.upsert(owner, entry);
    return entry;
  }

  Future<void> deleteEntry(String id) async {
    final context = _client.sessionGeneration;
    final owner = await currentOwner;
    if (owner != null) await store.hasSnapshot(owner);
    _client.ensureSession(context);
    await _client.delete(ApiConfig.journalEntryUrl(id));
    if (owner != null) await store.delete(owner, id);
  }

  Future<List<JournalMediaModel>> listMedia(String entryId) async {
    final response = await _client.get(ApiConfig.journalMediaUrl(entryId));
    return decodeListResponse(response, JournalMediaModel.fromJson);
  }

  Future<JournalMediaModel> addMedia({
    required String entryId,
    required String url,
    String? type,
  }) async {
    final response = await _client.post(
      ApiConfig.journalMediaUrl(entryId),
      body: {'url': url, 'type': ?type},
    );
    return decodeResponse(response, JournalMediaModel.fromJson);
  }

  Future<void> deleteMedia({
    required String entryId,
    required String mediaId,
  }) async {
    await _client.delete(ApiConfig.journalMediaItemUrl(entryId, mediaId));
  }
}
