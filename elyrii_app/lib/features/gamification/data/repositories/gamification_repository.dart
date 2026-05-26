import '../../../../core/network/api_client.dart';
import '../../../../core/config/api_config.dart';
import '../models/gamification_models.dart';

/// Repository handling quest/challenge API calls
class GamificationRepository {
  final ApiClient _client;

  GamificationRepository({required ApiClient client}) : _client = client;

  /// Parse a list response into UserChallenge objects
  List<UserChallenge> _parseList(dynamic response) {
    final List<dynamic> data =
        response is List ? response : (response['data'] ?? []);
    return data
        .map((e) => UserChallenge.fromJson(e as Map<String, dynamic>))
        .toList();
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
    final response =
        await _client.post(ApiConfig.acceptChallengeUrl(challengeId))
            as Map<String, dynamic>;
    return UserChallenge.fromJson(response);
  }

  /// Reject a proposed challenge
  Future<UserChallenge> rejectChallenge(String challengeId) async {
    final response =
        await _client.post(ApiConfig.rejectChallengeUrl(challengeId))
            as Map<String, dynamic>;
    return UserChallenge.fromJson(response);
  }

  /// Fetch SYSTEM challenges not yet started by the user
  Future<List<ChallengeTemplate>> getAvailableChallenges() async {
    final response = await _client.get(ApiConfig.availableChallengesUrl);
    final List<dynamic> data =
        response is List ? response : (response['data'] ?? []);
    return data
        .map((e) => ChallengeTemplate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Start a SYSTEM challenge (assigns it as ACTIVE)
  Future<UserChallenge> startChallenge(String challengeId) async {
    final response = await _client
        .post(ApiConfig.startChallengeUrl(challengeId)) as Map<String, dynamic>;
    // Backend returns { challenge, userChallenge }
    if (response['userChallenge'] is Map<String, dynamic>) {
      final uc = UserChallenge.fromJson(
        response['userChallenge'] as Map<String, dynamic>,
      );
      // Attach the template from the response
      if (response['challenge'] is Map<String, dynamic>) {
        final tpl = ChallengeTemplate.fromJson(
          response['challenge'] as Map<String, dynamic>,
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
    return UserChallenge.fromJson(response);
  }
}
