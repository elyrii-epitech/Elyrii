import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/dashboard_models.dart';

class DashboardRepository {
  static const String _cacheKey = 'cache_dashboard_data';

  final ApiClient _client;
  SharedPreferences? _prefs;

  DashboardRepository({required ApiClient client, SharedPreferences? prefs})
    : _client = client,
      _prefs = prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<DashboardData?> getCachedDashboard() async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = prefs.getString(_cacheKey);
      if (jsonStr == null || jsonStr.isEmpty) return null;
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return DashboardData.fromJson(map);
    } catch (e) {
      debugPrint('[DashboardRepository] Cache read error: $e');
      return null;
    }
  }

  Future<DashboardData> getDashboard({String range = '30d'}) async {
    try {
      final response =
          (await _client.get(
                ApiConfig.userDashboardUrl,
                queryParams: {'range': range},
              ))
              as Map<String, dynamic>;

      // Sauvegarde du cache offline
      unawaited(
        _getPrefs()
            .then((prefs) {
              prefs.setString(_cacheKey, jsonEncode(response));
            })
            .catchError((_) {}),
      );

      return DashboardData.fromJson(response);
    } catch (e) {
      debugPrint(
        '[DashboardRepository] Network failed, falling back to local cache: $e',
      );
      final cached = await getCachedDashboard();
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  Future<DashboardStats> getStats({String range = '30d'}) async {
    final response =
        (await _client.get(
              ApiConfig.userStatsUrl,
              queryParams: {'range': range},
            ))
            as Map<String, dynamic>;
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
