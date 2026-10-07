import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/json_response.dart';
import '../../../../core/diagnostics/app_diagnostics.dart';
import '../models/dashboard_models.dart';

class DashboardRepository {
  static const _cacheKey = 'cache_dashboard_data';
  static const cacheLifetime = Duration(hours: 24);
  final ApiClient _client;
  final DateTime Function() _now;
  SharedPreferences? _prefs;
  String _storageScope = 'guest';
  int _generation = 0;

  DashboardRepository({
    required this._client,
    this._prefs,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  void onUserChanged({String? userId, bool isDemo = false}) {
    _generation++;
    _storageScope = isDemo ? 'demo' : userId ?? 'guest';
  }

  Future<SharedPreferences> _getPrefs() async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<DashboardData?> getCachedDashboard({
    String? scope,
    String range = '30d',
  }) async {
    final prefs = await _getPrefs();
    final expectedOwner = scope ?? _storageScope;
    final key = '${_cacheKey}_${expectedOwner}_$range';
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['owner'] != null && map['owner'] != expectedOwner) {
        throw const FormatException('Dashboard cache account mismatch');
      }
      final fetchedAt = DateTime.parse(map['fetchedAt'] as String);
      final age = _now().difference(fetchedAt);
      if (age.isNegative || age > cacheLifetime) return null;
      return DashboardData.fromJson(
        map['data'] as Map<String, dynamic>,
        cachedAt: fetchedAt,
      );
    } catch (error) {
      AppDiagnostics.record('dashboard_cache_invalid', error);
      await prefs.remove(key);
      return null;
    }
  }

  Future<DashboardData> getDashboard({String range = '30d'}) async {
    final scope = _storageScope;
    final generation = _generation;
    try {
      final response = await _client.get(
        ApiConfig.userDashboardUrl,
        queryParams: {'range': range},
      );
      final parsed = decodeResponse(response, DashboardData.fromJson);
      final prefs = await _getPrefs();
      if (generation == _generation) {
        try {
          await prefs.setString(
            '${_cacheKey}_${scope}_$range',
            jsonEncode({
              'owner': scope,
              'fetchedAt': _now().toUtc().toIso8601String(),
              'data': response,
            }),
          );
        } catch (error) {
          AppDiagnostics.record('dashboard_cache_write_failed', error);
        }
      }
      return parsed;
    } catch (error) {
      // Session, validation and protocol failures must never appear as offline success.
      if (error is! ApiException ||
          !error.canUseOfflineData ||
          generation != _generation) {
        rethrow;
      }
      final cached = await getCachedDashboard(scope: scope, range: range);
      if (cached == null) rethrow;
      return cached;
    }
  }

  Future<DashboardStats> getStats({String range = '30d'}) async =>
      decodeResponse(
        await _client.get(
          ApiConfig.userStatsUrl,
          queryParams: {'range': range},
        ),
        DashboardStats.fromJson,
      );
  Future<String?> getLatestMood() async =>
      (await _client.get(ApiConfig.latestMoodUrl)
              as Map<String, dynamic>)['moodType']
          as String?;
  Future<void> logMood(String moodType) async {
    await _client.post(ApiConfig.logMoodUrl, body: {'moodType': moodType});
  }
}
