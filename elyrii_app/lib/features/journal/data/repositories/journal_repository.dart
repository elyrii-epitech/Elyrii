import '../../../../core/network/api_client.dart';
import '../../../../core/config/api_config.dart';
import '../models/journal_entry_model.dart';

/// Repository handling journal API calls
class JournalRepository {
  final ApiClient _client;

  JournalRepository({required ApiClient client}) : _client = client;

  /// Fetch all journal entries, optionally filtered by date range
  Future<List<JournalEntryModel>> getEntries({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
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
    return data
        .map((e) => JournalEntryModel.fromJson(e as Map<String, dynamic>))
        .toList();
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
