/// API endpoint configuration
/// All requests go through the gateway service
class ApiConfig {
  ApiConfig._();

  static const String _defaultBaseUrl = 'http://localhost:3000';

  static String _baseUrl = _defaultBaseUrl;
  static String get baseUrl => _baseUrl;

  /// Override the gateway base URL (e.g. for staging/production)
  static void setBaseUrl(String url) {
    _baseUrl = url;
  }

  // ==================== Auth ====================
  static String get loginUrl => '$_baseUrl/auth/login';
  static String get registerUrl => '$_baseUrl/auth/register';
  static String get logoutUrl => '$_baseUrl/auth/logout';
  static String get refreshUrl => '$_baseUrl/auth/refresh';

  // ==================== Journal ====================
  static String get journalUrl => '$_baseUrl/journal';
  static String journalEntryUrl(String id) => '$_baseUrl/journal/$id';

  // ==================== Chat (WebSocket) ====================
  static String chatWsUrl({String? userId}) {
    final params = <String, String>{};
    if (userId != null && userId.isNotEmpty) {
      params['userId'] = userId;
    }

    final wsBaseUrl = _baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
    final uri = Uri.parse('$wsBaseUrl/chat/ws');
    return params.isEmpty
        ? uri.toString()
        : uri.replace(queryParameters: params).toString();
  }

  // ==================== Quest / Challenge ====================
  static String get availableChallengesUrl => '$_baseUrl/challenge/available';
  static String startChallengeUrl(String id) =>
      '$_baseUrl/challenge/available/$id/start';
  static String get activeChallengesUrl => '$_baseUrl/challenge/active';
  static String get completedChallengesUrl => '$_baseUrl/challenge/completed';
  static String get proposalsUrl => '$_baseUrl/challenge/proposals';
  static String acceptChallengeUrl(String id) =>
      '$_baseUrl/challenge/proposals/$id/accept';
  static String rejectChallengeUrl(String id) =>
      '$_baseUrl/challenge/proposals/$id/reject';

  // ==================== User Profile ====================
  static String get userMeUrl => '$_baseUrl/user/me';
  static String get userDashboardUrl => '$_baseUrl/user/dashboard';
  static String get userStatsUrl => '$_baseUrl/user/stats';
  static String get userSettingsUrl => '$_baseUrl/user/settings';
  static String get userMascotUrl => '$_baseUrl/user/mascot';
  static String get userAvatarUrl => '$_baseUrl/user/avatar';
  static String get userAccountUrl => '$_baseUrl/user/account';
  static String get logMoodUrl => '$_baseUrl/user/mood';
  static String get latestMoodUrl => '$_baseUrl/user/mood/latest';

  // ==================== Coach ====================
  static String get coachSessionsUrl => '$_baseUrl/coach/sessions';

  // ==================== Meditation ====================
  static String get meditationCatalogUrl => '$_baseUrl/meditation/catalog';
  static String get meditationSessionsUrl => '$_baseUrl/meditation/sessions';
  static String get startMeditationSessionUrl =>
      '$_baseUrl/meditation/sessions/start';
  static String completeMeditationSessionUrl(String id) =>
      '$_baseUrl/meditation/sessions/$id/complete';
  static String cancelMeditationSessionUrl(String id) =>
      '$_baseUrl/meditation/sessions/$id/cancel';

  // ==================== Journal Media ====================
  static String journalMediaUrl(String entryId) =>
      '$_baseUrl/journal/$entryId/media';
  static String journalMediaItemUrl(String entryId, String mediaId) =>
      '$_baseUrl/journal/$entryId/media/$mediaId';
}
