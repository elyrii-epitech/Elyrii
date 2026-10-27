import 'package:flutter_test/flutter_test.dart';
import 'package:elyrii_app/features/dashboard/data/models/dashboard_models.dart';
import 'package:elyrii_app/features/dashboard/domain/civil_day.dart';
import 'package:elyrii_app/features/dashboard/presentation/mood_presentation.dart';
import 'package:elyrii_app/features/meditation/data/models/meditation_session_model.dart';
import 'package:elyrii_app/features/reviews/domain/review_period.dart';

void main() {
  test(
    'calendar month is split into seven exhaustive nonoverlapping periods',
    () {
      final window = ReviewWindow(
        period: ReviewPeriod.month,
        today: CivilDay(2026, 10, 31),
      );
      final days = window.buckets.expand((days) => days).toList();
      expect(window.range, '31d');
      expect(window.buckets, hasLength(7));
      expect(days, hasLength(31));
      expect(days.toSet(), hasLength(31));
      expect(days.first, CivilDay(2026, 10, 1));
      expect(days.last, CivilDay(2026, 10, 31));
      final sizes = window.buckets.map((days) => days.length).toSet();
      expect(sizes, {4, 5});
    },
  );
  test(
    'arrival bounds the request and missing moods never become server counts',
    () {
      final window = ReviewWindow(
        period: ReviewPeriod.week,
        today: CivilDay(2026, 10, 23),
        createdAt: DateTime(2026, 10, 21),
      );
      final projection = projectReview(
        window: window,
        moodDays: {CivilDay(2026, 10, 22): MoodType.happy},
        timeline: [
          ActivityTimelinePoint(
            day: CivilDay(2026, 10, 23),
            moodLogs: 80,
            journalEntries: 2,
          ),
        ],
        sessions: [],
      );
      expect(window.range, '3d');
      expect(
        projection.columns.where((column) => column.mood != null).single.mood,
        MoodType.happy,
      );
      expect(projection.journalTotal, 2);
      expect(projection.calmTotal, 0);
      expect(projection.columns.last.mood, isNull);
    },
  );
  test('completed calm only and capped session history remains unknown before coverage', () {
    final window = ReviewWindow(
      period: ReviewPeriod.month,
      today: CivilDay(2026, 10, 31),
    );
    final sessions = List.generate(
      100,
      (index) => MeditationSessionModel(
        id: '$index',
        type: 'COHERENCE',
        durationMinutes: 2,
        status: index == 0 ? 'CANCELLED' : 'COMPLETED',
        createdAt: DateTime(2026, 10, 25),
      ),
    );
    final projection = projectReview(
      window: window,
      moodDays: {},
      timeline: [],
      sessions: sessions,
    );
    expect(projection.partialCalm, isTrue);
    expect(projection.columns.first.calm, isNull);
    expect(projection.calmTotal, 198);
  });
  test('period mood is a rounded mean of known local days only', () {
    final window = ReviewWindow(
      period: ReviewPeriod.month,
      today: CivilDay(2026, 10, 31),
    );
    final projection = projectReview(
      window: window,
      moodDays: {
        CivilDay(2026, 10, 1): MoodType.neutral,
        CivilDay(2026, 10, 2): MoodType.veryHappy,
      },
      timeline: [],
      sessions: [],
    );
    expect(projection.columns.first.mood, MoodType.happy);
    expect(projection.columns.last.mood, isNull);
  });
}
