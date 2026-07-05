class MoodTrendPoint {
  final String day;
  final int count;

  const MoodTrendPoint({required this.day, required this.count});

  factory MoodTrendPoint.fromJson(Map<String, dynamic> json) {
    return MoodTrendPoint(
      day: json['day'] as String? ?? '',
      count: _readInt(json['count']),
    );
  }
}

class MoodDistributionItem {
  final String moodType;
  final int count;

  const MoodDistributionItem({required this.moodType, required this.count});

  factory MoodDistributionItem.fromJson(Map<String, dynamic> json) {
    return MoodDistributionItem(
      moodType: json['moodType'] as String? ?? '',
      count: _readInt(json['count']),
    );
  }
}

class ActivityTimelinePoint {
  final String day;
  final int moodLogs;
  final int journalEntries;

  const ActivityTimelinePoint({
    required this.day,
    required this.moodLogs,
    required this.journalEntries,
  });

  factory ActivityTimelinePoint.fromJson(Map<String, dynamic> json) {
    return ActivityTimelinePoint(
      day: json['day'] as String? ?? '',
      moodLogs: _readInt(json['moodLogs']),
      journalEntries: _readInt(json['journalEntries']),
    );
  }
}

class DashboardStats {
  final int rangeDays;
  final int streak;
  final int moodLogsCount;
  final int journalEntriesCount;
  final int activeChallengesCount;
  final int completedChallengesCount;
  final int totalPoints;
  final int meditationSessionsCount;
  final int coachSessionsCount;
  final String? latestMood;
  final List<MoodTrendPoint> moodTrend7Days;
  final List<MoodDistributionItem> moodDistribution;
  final List<ActivityTimelinePoint> activityTimeline;

  const DashboardStats({
    required this.rangeDays,
    required this.streak,
    required this.moodLogsCount,
    required this.journalEntriesCount,
    required this.activeChallengesCount,
    required this.completedChallengesCount,
    required this.totalPoints,
    required this.meditationSessionsCount,
    required this.coachSessionsCount,
    this.latestMood,
    required this.moodTrend7Days,
    required this.moodDistribution,
    required this.activityTimeline,
  });

  factory DashboardStats.empty() {
    return const DashboardStats(
      rangeDays: 7,
      streak: 0,
      moodLogsCount: 0,
      journalEntriesCount: 0,
      activeChallengesCount: 0,
      completedChallengesCount: 0,
      totalPoints: 0,
      meditationSessionsCount: 0,
      coachSessionsCount: 0,
      latestMood: null,
      moodTrend7Days: [],
      moodDistribution: [],
      activityTimeline: [],
    );
  }

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      rangeDays: _readInt(json['rangeDays']) == 0
          ? 7
          : _readInt(json['rangeDays']),
      streak: _readInt(json['streak']),
      moodLogsCount: _readInt(json['moodLogsCount']),
      journalEntriesCount: _readInt(json['journalEntriesCount']),
      activeChallengesCount: _readInt(json['activeChallengesCount']),
      completedChallengesCount: _readInt(json['completedChallengesCount']),
      totalPoints: _readInt(json['totalPoints']),
      meditationSessionsCount: _readInt(json['meditationSessionsCount']),
      coachSessionsCount: _readInt(json['coachSessionsCount']),
      latestMood: json['latestMood'] as String?,
      moodTrend7Days: (json['moodTrend7Days'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                MoodTrendPoint.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      moodDistribution: (json['moodDistribution'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => MoodDistributionItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      activityTimeline: (json['activityTimeline'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => ActivityTimelinePoint.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }

  double get completionRate {
    final attempts = completedChallengesCount + activeChallengesCount;
    if (attempts == 0) return 0.0;
    return completedChallengesCount / attempts;
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
