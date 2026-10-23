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
    // The streak's seven days are active, the eighth breaks it, and older
    // days follow a fixed rhythm so the calendar shows a lived month.
    bool active(int daysAgo) =>
        daysAgo < streakDays || (daysAgo > streakDays && daysAgo % 4 != 1);
    final activeDays = [
      for (var daysAgo = rangeDays - 1; daysAgo >= 0; daysAgo--)
        if (active(daysAgo)) daysAgo,
    ];
    return {
      'rangeDays': rangeDays,
      'streak': streakDays,
      'completedChallengesCount': completedChallengeCount,
      'totalPoints': totalPoints,
      'moodLogsCount': activeDays.length,
      'moodTrend7Days': [
        for (var i = 0; i < 7; i++)
          {'day': dayOf(now.subtract(Duration(days: 6 - i))), 'count': 1},
      ],
      'moodDistribution': [
        {'moodType': 'happy', 'count': activeDays.length},
      ],
      'activityTimeline': [
        for (final daysAgo in activeDays)
          {
            'day': dayOf(DateTime(now.year, now.month, now.day - daysAgo)),
            'moodLogs': 1,
            'journalEntries': daysAgo == 0 ? journalCount : 0,
          },
      ],
    };
  }

  /// Deterministic demo completion dates: one finished challenge per day,
  /// the most recent today, so the week parterre, the older unlocks and the
  /// calendar all agree without a server.
  static DateTime challengeCompletedAt(int index, DateTime now) =>
      now.subtract(Duration(days: index));
}
