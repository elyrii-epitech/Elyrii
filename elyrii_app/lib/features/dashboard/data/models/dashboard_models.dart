class DashboardStats {
  final int streak;
  final int moodLogsCount;
  final int journalEntriesCount;
  final int activeChallengesCount;
  final int completedChallengesCount;
  final int totalPoints;
  final int meditationSessionsCount;
  final int coachSessionsCount;
  final String? latestMood;

  const DashboardStats({
    required this.streak,
    required this.moodLogsCount,
    required this.journalEntriesCount,
    required this.activeChallengesCount,
    required this.completedChallengesCount,
    required this.totalPoints,
    required this.meditationSessionsCount,
    required this.coachSessionsCount,
    this.latestMood,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      streak: _readInt(json['streak']),
      moodLogsCount: _readInt(json['moodLogsCount']),
      journalEntriesCount: _readInt(json['journalEntriesCount']),
      activeChallengesCount: _readInt(json['activeChallengesCount']),
      completedChallengesCount: _readInt(json['completedChallengesCount']),
      totalPoints: _readInt(json['totalPoints']),
      meditationSessionsCount: _readInt(json['meditationSessionsCount']),
      coachSessionsCount: _readInt(json['coachSessionsCount']),
      latestMood: json['latestMood'] as String?,
    );
  }
}

class DashboardData {
  final String? latestMood;
  final DashboardStats stats;
  final List<dynamic> activeChallenges;
  final List<dynamic> pendingChallenges;

  const DashboardData({
    required this.latestMood,
    required this.stats,
    required this.activeChallenges,
    required this.pendingChallenges,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final challenges = json['challenges'] as Map? ?? const {};
    return DashboardData(
      latestMood: json['latestMood'] as String?,
      stats: DashboardStats.fromJson(
        json['stats'] as Map<String, dynamic>? ?? json,
      ),
      activeChallenges: List<dynamic>.from(challenges['active'] as List? ?? []),
      pendingChallenges: List<dynamic>.from(
        challenges['pending'] as List? ?? [],
      ),
    );
  }
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
