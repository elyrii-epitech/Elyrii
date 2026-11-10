import '../../../../core/network/json_response.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/config/api_config.dart';
import '../models/gamification_models.dart';

/// Repository handling quest/challenge API calls
class GamificationRepository {
  final ApiClient _client;

  GamificationRepository({required this._client});

  Future<List<T>> _pages<T>(
    String url,
    T Function(Map<String, dynamic>) decode, {
    bool owned = false,
  }) async {
    final generation = _client.sessionGeneration;
    final owner = await _client.currentUserId;
    final result = <T>[];
    final ids = <String>{};
    final cursors = <String>{};
    Map<String, String>? cursor;
    while (true) {
      _client.ensureSession(generation);
      final response = await _client.get(
        url,
        queryParams: {'pageSize': '100', ...?cursor},
      );
      _client.ensureSession(generation);
      final page = response is List
          ? response
          : decodeResponse(response, (json) {
              final items = json['items'] as List;
              if (items.length > 100) {
                throw const FormatException('Invalid challenge page');
              }
              return items;
            });
      final decoded = decodeListResponse(page, (json) {
        final id = json['id'] as String;
        if (id.isEmpty || (owned && owner != null && json['userId'] != owner)) {
          throw const FormatException('Challenge identity mismatch');
        }
        return decode(json);
      });
      for (var i = 0; i < page.length; i++) {
        if (ids.add((page[i] as Map)['id'] as String)) result.add(decoded[i]);
      }
      if (response is List || response['nextCursor'] == null) break;
      cursor = decodeResponse(response['nextCursor'], (json) {
        final date = json['createdAt'] as String;
        DateTime.parse(date);
        final id = json['id'] as String;
        if (page.isEmpty ||
            id != (page.last as Map)['id'] ||
            !cursors.add('$date/$id')) {
          throw const FormatException('Invalid challenge cursor');
        }
        return {'cursorDate': date, 'cursorId': id};
      });
    }
    return List.unmodifiable(result);
  }

  /// Fetch active challenges for the authenticated user
  Future<List<UserChallenge>> getActiveChallenges() async {
    return _pages(
      ApiConfig.activeChallengesUrl,
      UserChallenge.fromJson,
      owned: true,
    );
  }

  /// Fetch completed challenges for the authenticated user
  Future<List<UserChallenge>> getCompletedChallenges() async {
    return _pages(
      ApiConfig.completedChallengesUrl,
      UserChallenge.fromJson,
      owned: true,
    );
  }

  /// Fetch pending challenge proposals
  Future<List<UserChallenge>> getProposals() async {
    return _pages(ApiConfig.proposalsUrl, UserChallenge.fromJson, owned: true);
  }

  /// Accept a proposed challenge
  Future<UserChallenge> acceptChallenge(String challengeId) async {
    final response = await _client.post(
      ApiConfig.acceptChallengeUrl(challengeId),
    );
    return decodeResponse(response, UserChallenge.fromJson);
  }

  /// Reject a proposed challenge
  Future<UserChallenge> rejectChallenge(String challengeId) async {
    final response = await _client.post(
      ApiConfig.rejectChallengeUrl(challengeId),
    );
    return decodeResponse(response, UserChallenge.fromJson);
  }

  /// Fetch SYSTEM challenges not yet started by the user
  Future<List<ChallengeTemplate>> getAvailableChallenges() async {
    return _pages(ApiConfig.availableChallengesUrl, ChallengeTemplate.fromJson);
  }

  /// Start a SYSTEM challenge (assigns it as ACTIVE)
  Future<UserChallenge> startChallenge(String challengeId) async {
    final response = await _client.post(
      ApiConfig.startChallengeUrl(challengeId),
    );
    return decodeResponse(response, _startedChallenge);
  }

  UserChallenge _startedChallenge(Map<String, dynamic> response) {
    // Backend returns { challenge, userChallenge }
    if (response['userChallenge'] is Map<String, dynamic>) {
      final uc = decodeResponse(
        response['userChallenge'],
        UserChallenge.fromJson,
      );
      // Attach the template from the response
      if (response['challenge'] is Map<String, dynamic>) {
        final tpl = decodeResponse(
          response['challenge'],
          ChallengeTemplate.fromJson,
        );
        return UserChallenge(
          id: uc.id,
          userId: uc.userId,
          challengeId: uc.challengeId,
          status: uc.status,
          progress: uc.progress,
          createdAt: uc.createdAt,
          updatedAt: uc.updatedAt,
          completedAt: uc.completedAt,
          template: tpl,
        );
      }
      return uc;
    }
    return decodeResponse(response, UserChallenge.fromJson);
  }
}
