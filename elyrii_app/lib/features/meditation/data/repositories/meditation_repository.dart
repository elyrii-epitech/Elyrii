import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/meditation_session_model.dart';

class MeditationRepository {
  final ApiClient _client;

  MeditationRepository({required ApiClient client}) : _client = client;

  Future<List<MeditationProgram>> getCatalog() async {
    final response = await _client.get(ApiConfig.meditationCatalogUrl);
    final List<dynamic> data = response is List
        ? response
        : (response['data'] ?? []);
    return data
        .map((item) => MeditationProgram.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<MeditationSessionModel>> getSessions({int limit = 20}) async {
    final response = await _client.get(
      ApiConfig.meditationSessionsUrl,
      queryParams: {'limit': '$limit'},
    );
    final List<dynamic> data = response is List
        ? response
        : (response['data'] ?? []);
    return data
        .map(
          (item) => MeditationSessionModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<MeditationSessionModel> startSession({
    required String type,
    required int durationMinutes,
    String? moodBefore,
  }) async {
    final response =
        await _client.post(
              ApiConfig.startMeditationSessionUrl,
              body: {
                'type': type,
                'durationMinutes': durationMinutes,
                if (moodBefore != null) 'moodBefore': moodBefore,
              },
            )
            as Map<String, dynamic>;
    return MeditationSessionModel.fromJson(response);
  }

  Future<MeditationSessionModel> completeSession({
    required String sessionId,
    String? moodBefore,
    String? moodAfter,
    String? notes,
  }) async {
    final response =
        await _client.post(
              ApiConfig.completeMeditationSessionUrl(sessionId),
              body: {
                'endedAt': DateTime.now().toUtc().toIso8601String(),
                if (moodBefore != null) 'moodBefore': moodBefore,
                if (moodAfter != null) 'moodAfter': moodAfter,
                if (notes != null) 'notes': notes,
              },
            )
            as Map<String, dynamic>;
    return MeditationSessionModel.fromJson(response);
  }

  Future<MeditationSessionModel> cancelSession(String sessionId) async {
    final response =
        await _client.post(ApiConfig.cancelMeditationSessionUrl(sessionId))
            as Map<String, dynamic>;
    return MeditationSessionModel.fromJson(response);
  }
}
