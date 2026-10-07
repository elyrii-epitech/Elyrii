import '../../../../core/network/json_response.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/config/api_config.dart';
import '../models/gamification_models.dart';

/// Repository handling quest/challenge API calls
class GamificationRepository {
  final ApiClient _client;

  GamificationRepository({required this._client});

  /// Parse a list response into UserChallenge objects
  List<UserChallenge> _parseList(dynamic response) {
    return decodeListResponse(response, UserChallenge.fromJson);
  }

  /// Fetch active challenges for the authenticated user
  Future<List<UserChallenge>> getActiveChallenges() async {
    final response = await _client.get(ApiConfig.activeChallengesUrl);
    return _parseList(response);
  }

  /// Fetch completed challenges for the authenticated user
  Future<List<UserChallenge>> getCompletedChallenges() async {
    final response = await _client.get(ApiConfig.completedChallengesUrl);
    return _parseList(response);
  }

  /// Fetch pending challenge proposals
  Future<List<UserChallenge>> getProposals() async {
    final response = await _client.get(ApiConfig.proposalsUrl);
    return _parseList(response);
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
    final response = await _client.get(ApiConfig.availableChallengesUrl);
    return decodeListResponse(response, ChallengeTemplate.fromJson);
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
