import '../../../../core/network/json_response.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/meditation_session_model.dart';

class MeditationRepository {
  final ApiClient _client;
  final int _sessionGeneration;

  MeditationRepository({required this._client})
    : _sessionGeneration = _client.sessionGeneration;

  void _ensureSession() => _client.ensureSession(_sessionGeneration);

  Future<List<MeditationSessionModel>> getSessions({int limit = 20}) async {
    _ensureSession();
    final response = await _client.get(
      ApiConfig.meditationSessionsUrl,
      queryParams: {'limit': '$limit'},
    );
    _ensureSession();
    return decodeListResponse(response, MeditationSessionModel.fromJson);
  }

  Future<MeditationSessionModel> startSession({
    required String type,
    required int durationMinutes,
    String? moodBefore,
    String? clientSessionId,
  }) async {
    _ensureSession();
    final response = await _client.post(
      ApiConfig.startMeditationSessionUrl,
      body: {
        'type': type,
        'durationMinutes': durationMinutes,
        'moodBefore': ?moodBefore,
        'clientSessionId': ?clientSessionId,
      },
    );
    _ensureSession();
    return decodeResponse(response, MeditationSessionModel.fromJson);
  }

  Future<MeditationSessionModel> completeSession({
    required String sessionId,
    String? moodBefore,
    String? moodAfter,
    String? notes,
  }) async {
    _ensureSession();
    final response = await _client.post(
      ApiConfig.completeMeditationSessionUrl(sessionId),
      body: {
        'moodBefore': ?moodBefore,
        'moodAfter': ?moodAfter,
        'notes': ?notes,
      },
    );
    _ensureSession();
    return decodeResponse(response, MeditationSessionModel.fromJson);
  }

  Future<MeditationSessionModel> cancelSession(String sessionId) async {
    _ensureSession();
    final response = await _client.post(
      ApiConfig.cancelMeditationSessionUrl(sessionId),
    );
    _ensureSession();
    return decodeResponse(response, MeditationSessionModel.fromJson);
  }
}
