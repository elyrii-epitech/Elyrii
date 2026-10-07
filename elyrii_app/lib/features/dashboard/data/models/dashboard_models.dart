import '../../../../core/data/json_contract.dart';

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

  DashboardStats({
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
    required List<MoodTrendPoint> moodTrend7Days,
    required List<MoodDistributionItem> moodDistribution,
    required List<ActivityTimelinePoint> activityTimeline,
  }) : moodTrend7Days = List.unmodifiable(moodTrend7Days),
       moodDistribution = List.unmodifiable(moodDistribution),
       activityTimeline = List.unmodifiable(activityTimeline);

  factory DashboardStats.empty() {
    return DashboardStats(
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
            (item) => MoodTrendPoint.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      moodDistribution: (json['moodDistribution'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                MoodDistributionItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      activityTimeline: (json['activityTimeline'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                ActivityTimelinePoint.fromJson(Map<String, dynamic>.from(item)),
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
  final DateTime? cachedAt;
  final DashboardStats stats;
  final List<dynamic> activeChallenges;
  final List<dynamic> pendingChallenges;

  DashboardData({
    this.cachedAt,
    required this.latestMood,
    required this.stats,
    required List<dynamic> activeChallenges,
    required List<dynamic> pendingChallenges,
  }) : activeChallenges = freezeJson(activeChallenges) as List<dynamic>,
       pendingChallenges = freezeJson(pendingChallenges) as List<dynamic>;

  factory DashboardData.fromJson(
    Map<String, dynamic> json, {
    DateTime? cachedAt,
  }) {
    final challenges = json['challenges'] as Map? ?? const {};
    return DashboardData(
      cachedAt: cachedAt,
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
