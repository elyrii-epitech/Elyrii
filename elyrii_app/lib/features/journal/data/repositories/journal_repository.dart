import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/config/api_config.dart';
import '../models/journal_entry_model.dart';

/// Repository handling journal API calls with automatic offline-first caching
class JournalRepository {
  static const String _cacheKey = 'cache_journal_entries';

  final ApiClient _client;
  SharedPreferences? _prefs;

  JournalRepository({required ApiClient client, SharedPreferences? prefs})
    : _client = client,
      _prefs = prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// Retrieve cached entries from local storage without network latency
  Future<List<JournalEntryModel>> getCachedEntries({String? owner}) async {
    try {
      owner ??= await _client.currentUserId;
      if (owner == null || owner.isEmpty) return const [];
      final prefs = await _getPrefs();
      final jsonStr =
          prefs.getString('${_cacheKey}_$owner') ?? prefs.getString(_cacheKey);
      if (jsonStr == null || jsonStr.isEmpty) return const [];
      final List<dynamic> list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => JournalEntryModel.fromJson(e as Map<String, dynamic>))
          .where((entry) => entry.userId == owner)
          .toList();
    } catch (e) {
      debugPrint('[JournalRepository] Cache read error: $e');
      return const [];
    }
  }

  Future<void> _saveCache(
    List<JournalEntryModel> entries,
    String? owner,
  ) async {
    if (owner == null || owner.isEmpty) return;
    try {
      final prefs = await _getPrefs();
      final jsonList = entries.map((e) => e.toCacheJson()).toList();
      await prefs.setString('${_cacheKey}_$owner', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[JournalRepository] Cache write error: $e');
    }
  }

  /// Fetch all journal entries with automatic offline fallback
  Future<List<JournalEntryModel>> getEntries({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final owner = await _client.currentUserId;
    try {
      final queryParams = <String, String>{};
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }
      final response = await _client.get(
        ApiConfig.journalUrl,
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );
      final List<dynamic> data = response is List
          ? response
          : (response['data'] ?? []);
      final entries = data
          .map((e) => JournalEntryModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // Mettre à jour le cache local offline
      if (startDate == null && endDate == null) {
        unawaited(_saveCache(entries, owner));
      }

      return entries;
    } catch (e) {
      if (e is ApiException && (e.statusCode == 401 || e.statusCode == 403)) {
        rethrow;
      }
      // Do not resolve a different account while this request is in flight.
      if (owner == null || owner.isEmpty) rethrow;
      debugPrint(
        '[JournalRepository] Network failed, falling back to local cache: $e',
      );
      final cached = (await getCachedEntries(owner: owner))
          .where(
            (entry) =>
                (startDate == null || !entry.createdAt.isBefore(startDate)) &&
                (endDate == null || !entry.createdAt.isAfter(endDate)),
          )
          .toList();
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  /// Fetch a single journal entry by ID
  Future<JournalEntryModel> getEntryById(String id) async {
    final response = await _client.get(ApiConfig.journalEntryUrl(id));
    return JournalEntryModel.fromJson(response as Map<String, dynamic>);
  }

  /// Create a new journal entry
  Future<JournalEntryModel> createEntry({
    required String title,
    String? content,
    String? mood,
    List<String>? tags,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'userId': '', // Backend overrides this from JWT
      'content': content,
      'mood': mood,
      'tags': tags,
    };
    final response =
        await _client.post(ApiConfig.journalUrl, body: body)
            as Map<String, dynamic>;
    final entryData = response['body'] ?? response;
    return JournalEntryModel.fromJson(entryData as Map<String, dynamic>);
  }

  /// Update an existing journal entry
  Future<JournalEntryModel> updateEntry({
    required String id,
    String? title,
    String? content,
    String? mood,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (content != null) body['content'] = content;
    if (mood != null) body['mood'] = mood;
    final response =
        await _client.put(ApiConfig.journalEntryUrl(id), body: body)
            as Map<String, dynamic>;
    final entryData = response['body'] ?? response;
    return JournalEntryModel.fromJson(entryData as Map<String, dynamic>);
  }

  /// Soft-delete a journal entry
  Future<void> deleteEntry(String id) async {
    await _client.delete(ApiConfig.journalEntryUrl(id));
  }

  Future<List<JournalMediaModel>> listMedia(String entryId) async {
    final response = await _client.get(ApiConfig.journalMediaUrl(entryId));
    final List<dynamic> data = response is List
        ? response
        : (response['data'] ?? []);
    return data
        .map((item) => JournalMediaModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<JournalMediaModel> addMedia({
    required String entryId,
    required String url,
    String? type,
  }) async {
    final response =
        await _client.post(
              ApiConfig.journalMediaUrl(entryId),
              body: {'url': url, 'type': ?type},
            )
            as Map<String, dynamic>;
    return JournalMediaModel.fromJson(response);
  }

  Future<void> deleteMedia({
    required String entryId,
    required String mediaId,
  }) async {
    await _client.delete(ApiConfig.journalMediaItemUrl(entryId, mediaId));
  }
}
