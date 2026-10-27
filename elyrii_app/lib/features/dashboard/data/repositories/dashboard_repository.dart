import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/json_response.dart';
import '../../../../core/diagnostics/app_diagnostics.dart';
import '../../../../core/storage/content_cipher.dart';
import '../models/dashboard_models.dart';

class DashboardRepository {
  static const _cacheKey = 'cache_dashboard_data';
  static const cacheLifetime = Duration(hours: 24);
  final ApiClient _client;
  final DateTime Function() _now;
  SharedPreferences? _prefs;
  Future<SharedPreferences>? _readyPrefs;
  ContentCipher get _cipher => ContentCipher(_client.storage);
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

  Future<SharedPreferences> _getPrefs() => _readyPrefs ??= _preparePrefs();

  Future<SharedPreferences> _preparePrefs() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where(
      (key) => key.startsWith(_cacheKey),
    )) {
      final value = prefs.getString(key);
      if (value != null && !value.startsWith('aesgcm1:')) {
        await prefs.remove(key);
      }
    }
    return prefs;
  }

  Future<DashboardData?> getCachedDashboard({
    String? scope,
    String range = '30d',
  }) async {
    final expectedOwner = scope ?? _storageScope;
    final prefs = await _getPrefs();
    final key = '${_cacheKey}_${expectedOwner}_$range';
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      // Discard legacy plaintext instead of continuing to retain sensitive
      // moods. A fresh request can recreate the cache under the account key.
      if (!raw.startsWith('aesgcm1:')) {
        await prefs.remove(key);
        return null;
      }
      final clear = await _cipher.open(
        expectedOwner,
        raw,
        purpose: 'dashboard:$range',
      );
      final map = jsonDecode(clear) as Map<String, dynamic>;
      if (map['owner'] != null && map['owner'] != expectedOwner) {
        throw const FormatException('Dashboard cache account mismatch');
      }
      final fetchedAt = DateTime.parse(map['fetchedAt'] as String);
      final age = _now().difference(fetchedAt);
      if (age.isNegative || age > cacheLifetime) {
        await prefs.remove(key);
        return null;
      }
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
          final encrypted = await _cipher.seal(
            scope,
            jsonEncode({
              'owner': scope,
              'fetchedAt': _now().toUtc().toIso8601String(),
              'data': response,
            }),
            purpose: 'dashboard:$range',
          );
          if (generation == _generation) {
            await prefs.setString('${_cacheKey}_${scope}_$range', encrypted);
          }
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
  Future<void> logMood(String moodType) async {
    await _client.post(ApiConfig.logMoodUrl, body: {'moodType': moodType});
  }
}
