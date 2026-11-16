import 'dart:math' as math;

import '../../dashboard/data/models/dashboard_models.dart';
import '../../dashboard/domain/civil_day.dart';
import '../../dashboard/presentation/mood_presentation.dart';
import '../../meditation/data/models/meditation_session_model.dart';

enum ReviewPeriod { week, month, quarter }

class ReviewWindow {
  final CivilDay start;
  final CivilDay end;
  final ReviewPeriod period;
  ReviewWindow({
    required this.period,
    required CivilDay today,
    DateTime? createdAt,
  }) : end = today,
       start = _start(period, today, createdAt);
  static CivilDay _start(
    ReviewPeriod period,
    CivilDay today,
    DateTime? createdAt,
  ) {
    final base = switch (period) {
      ReviewPeriod.week => today.addDays(-6),
      ReviewPeriod.month => today.civilMonth.firstDay,
      ReviewPeriod.quarter => today.addDays(-89),
    };
    final joined = createdAt == null ? null : CivilDay.fromLocal(createdAt);
    return joined != null && joined.isAfter(base) && !joined.isAfter(today)
        ? joined
        : base;
  }

  int get dayCount => start.daysUntil(end) + 1;
  String get range => '${dayCount}d';
  List<List<CivilDay>> get buckets => List.generate(7, (index) {
    if (period == ReviewPeriod.week) {
      final day = end.addDays(index - 6);
      return day.isBefore(start) ? <CivilDay>[] : [day];
    }
    final from = index * dayCount ~/ 7;
    final until = (index + 1) * dayCount ~/ 7;
    return [
      for (var offset = from; offset < until; offset++) start.addDays(offset),
    ];
  });
}

class ReviewColumn {
  final List<CivilDay> days;
  final MoodType? mood;
  final int journal;
  final int? calm;
  const ReviewColumn({
    required this.days,
    required this.mood,
    required this.journal,
    required this.calm,
  });
}

class ReviewProjection {
  final List<ReviewColumn> columns;
  final bool partialCalm;
  const ReviewProjection({required this.columns, required this.partialCalm});
  int get journalTotal =>
      columns.fold(0, (sum, column) => sum + column.journal);
  int get calmTotal =>
      columns.fold(0, (sum, column) => sum + (column.calm ?? 0));
}

ReviewProjection projectReview({
  required ReviewWindow window,
  required Map<CivilDay, MoodType> moodDays,
  required List<ActivityTimelinePoint> timeline,
  required List<MeditationSessionModel> sessions,
}) {
  final journal = {
    for (final point in timeline) point.day: point.journalEntries,
  };
  final calm = <CivilDay, int>{};
  CivilDay? oldest;
  for (final session in sessions) {
    final day = CivilDay.fromLocal(session.endedAt ?? session.createdAt);
    if (oldest == null || day.isBefore(oldest)) oldest = day;
    if (session.status == 'COMPLETED') {
      calm.update(
        day,
        (minutes) => minutes + session.durationMinutes,
        ifAbsent: () => session.durationMinutes,
      );
    }
  }
  final partial =
      sessions.length >= 100 &&
      oldest != null &&
      !oldest.isBefore(window.start);
  return ReviewProjection(
    partialCalm: partial,
    columns: [
      for (final days in window.buckets)
        () {
          final moods = [
            for (final day in days)
              if (moodDays[day] != null) moodDays[day]!.index,
          ];
          final mood = moods.isEmpty
              ? null
              : MoodType.values[math.min(
                  MoodType.values.length - 1,
                  (moods.fold(0, (sum, value) => sum + value) / moods.length)
                      .round(),
                )];
          final covered =
              days.isNotEmpty && (!partial || !days.last.isBefore(oldest!));
          return ReviewColumn(
            days: List.unmodifiable(days),
            mood: mood,
            journal: days.fold(0, (sum, day) => sum + (journal[day] ?? 0)),
            calm: covered
                ? days.fold<int>(0, (sum, day) => sum + (calm[day] ?? 0))
                : null,
          );
        }(),
    ],
  );
}
