import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/dashboard_models.dart';

class DashboardRepository {
  final ApiClient _client;

  DashboardRepository({required ApiClient client}) : _client = client;

  Future<DashboardData> getDashboard({String range = '30d'}) async {
    final response = (await _client.get(
      ApiConfig.userDashboardUrl,
      queryParams: {'range': range},
    )) as Map<String, dynamic>;
    return DashboardData.fromJson(response);
  }

  Future<DashboardStats> getStats({String range = '30d'}) async {
    final response = (await _client.get(
      ApiConfig.userStatsUrl,
      queryParams: {'range': range},
    )) as Map<String, dynamic>;
    return DashboardStats.fromJson(response);
  }

  Future<String?> getLatestMood() async {
    final response =
        await _client.get(ApiConfig.latestMoodUrl) as Map<String, dynamic>;
    return response['moodType'] as String?;
  }

  Future<void> logMood(String moodType) async {
    await _client.post(ApiConfig.logMoodUrl, body: {'moodType': moodType});
  }
}
