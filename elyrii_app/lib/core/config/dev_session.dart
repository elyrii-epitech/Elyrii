import '../../features/mascot/data/models/mascot_accessory.dart';

/// Local development session adapted from Lucas's studio. Its data never
/// reaches the backend or another account's preferences.
abstract final class DevSession {
  static const userId = 'demo-user';
  static const email = 'demo@elyrii.local';
  static const firstName = 'Dorian';
  static int get completedChallengeCount =>
      MascotAccessories.maxRequiredChallenges;
  static int get jardinLevel => 1 + completedChallengeCount ~/ 3;
  static int get totalPoints => completedChallengeCount * 50;
  static const streakDays = 7;

  /// The synthetic stats payload of the demo session, relative to [now].
  /// `DemoApi` serves it and the dashboard's demo shortcut parses it, so
  /// both expose the same days without inventing server fields.
  static Map<String, dynamic> statsPayload({
    required DateTime now,
    int journalCount = 0,
    int rangeDays = 30,
  }) {
    String dayOf(DateTime date) =>
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final today = dayOf(now);
    return {
      'rangeDays': rangeDays,
      'streak': streakDays,
      'completedChallengesCount': completedChallengeCount,
      'totalPoints': totalPoints,
      'moodLogsCount': 7,
      'moodTrend7Days': [
        for (var i = 0; i < 7; i++)
          {'day': dayOf(now.subtract(Duration(days: 6 - i))), 'count': 1},
      ],
      'moodDistribution': [
        {'moodType': 'happy', 'count': 7},
      ],
      'activityTimeline': [
        {'day': today, 'moodLogs': 1, 'journalEntries': journalCount},
      ],
    };
  }

  /// Deterministic demo completion dates: one finished challenge per day,
  /// the most recent today, so the week parterre, the older unlocks and the
  /// calendar all agree without a server.
  static DateTime challengeCompletedAt(int index, DateTime now) =>
      now.subtract(Duration(days: index));
}
