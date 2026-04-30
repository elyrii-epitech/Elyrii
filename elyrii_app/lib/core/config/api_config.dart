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
  static String chatWsUrl(String userId) =>
      '${_baseUrl.replaceFirst('http', 'ws')}/chat/ws?userId=$userId';

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
  static String get userStatsUrl => '$_baseUrl/user/stats';
  static String get logMoodUrl => '$_baseUrl/user/mood';
  static String get latestMoodUrl => '$_baseUrl/user/mood/latest';
}
