import '../../../../core/network/json_response.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/meditation_session_model.dart';

class MeditationRepository {
  final ApiClient _client;

  MeditationRepository({required this._client});

  Future<List<MeditationProgram>> getCatalog() async {
    final response = await _client.get(ApiConfig.meditationCatalogUrl);
    return decodeListResponse(response, MeditationProgram.fromJson);
  }

  Future<List<MeditationSessionModel>> getSessions({int limit = 20}) async {
    final response = await _client.get(
      ApiConfig.meditationSessionsUrl,
      queryParams: {'limit': '$limit'},
    );
    return decodeListResponse(response, MeditationSessionModel.fromJson);
  }

  Future<MeditationSessionModel> startSession({
    required String type,
    required int durationMinutes,
    String? moodBefore,
  }) async {
    final response = await _client.post(
      ApiConfig.startMeditationSessionUrl,
      body: {
        'type': type,
        'durationMinutes': durationMinutes,
        'moodBefore': ?moodBefore,
      },
    );
    return decodeResponse(response, MeditationSessionModel.fromJson);
  }

  Future<MeditationSessionModel> completeSession({
    required String sessionId,
    String? moodBefore,
    String? moodAfter,
    String? notes,
  }) async {
    final response = await _client.post(
      ApiConfig.completeMeditationSessionUrl(sessionId),
      body: {
        'endedAt': DateTime.now().toUtc().toIso8601String(),
        'moodBefore': ?moodBefore,
        'moodAfter': ?moodAfter,
        'notes': ?notes,
      },
    );
    return decodeResponse(response, MeditationSessionModel.fromJson);
  }

  Future<MeditationSessionModel> cancelSession(String sessionId) async {
    final response = await _client.post(
      ApiConfig.cancelMeditationSessionUrl(sessionId),
    );
    return decodeResponse(response, MeditationSessionModel.fromJson);
  }
}
