import 'package:elyrii_app/features/dashboard/domain/civil_day.dart';
import 'package:elyrii_app/features/gamification/data/models/gamification_models.dart';
import 'package:elyrii_app/features/gamification/domain/garden_progress.dart';
import 'package:flutter_test/flutter_test.dart';

UserChallenge _challenge(
  String id, {
  required DateTime createdAt,
  DateTime? completedAt,
  String? status,
  DateTime? updatedAt,
}) => UserChallenge(
  id: id,
  userId: 'alice',
  challengeId: 'template-$id',
  status: status ?? (completedAt == null ? 'ACTIVE' : 'COMPLETED'),
  createdAt: createdAt,
  updatedAt: updatedAt ?? createdAt,
  completedAt: completedAt,
);

GardenDayProgress _on(List<GardenDayProgress> progress, int day) =>
    progress.firstWhere((entry) => entry.day.day == day);

final _october = CivilMonth(2026, 10);
final _endOfOctober = CivilDay(2026, 10, 31);

List<GardenDayProgress> _october2026({
  List<UserChallenge> active = const [],
  List<UserChallenge> completed = const [],
  CivilDay? today,
}) => buildGardenProgress(
  today: today ?? _endOfOctober,
  month: _october,
  activeChallenges: active,
  completedChallenges: completed,
);

void main() {
  test('returns every day of the month in order', () {
    final progress = buildGardenProgress(
      today: CivilDay(2028, 2, 29),
      month: CivilMonth(2028, 2),
      activeChallenges: const [],
      completedChallenges: const [],
    );

    expect(progress, hasLength(29));
    expect(progress.first.day, CivilDay(2028, 2, 1));
    expect(progress.last.day, CivilDay(2028, 2, 29));
  });

  test('a day with one completion and one ongoing challenge is 50%', () {
    final progress = _october2026(
      active: [_challenge('ongoing', createdAt: DateTime(2026, 10, 1, 9))],
      completed: [
        _challenge(
          'done',
          createdAt: DateTime(2026, 10, 1, 9),
          completedAt: DateTime(2026, 10, 10, 18),
        ),
      ],
    );

    final day = _on(progress, 10);
    expect(day.total, 2);
    expect(day.completed, 1);
    expect(day.completionRate, 0.5);
  });

  test('a finished challenge leaves the denominator the next day', () {
    final progress = _october2026(
      active: [_challenge('ongoing', createdAt: DateTime(2026, 10, 1))],
      completed: [
        _challenge(
          'done',
          createdAt: DateTime(2026, 10, 1),
          completedAt: DateTime(2026, 10, 10),
        ),
      ],
    );

    expect(_on(progress, 9).total, 2);
    expect(_on(progress, 9).completed, 0);
    final after = _on(progress, 11);
    expect(after.total, 1);
    expect(after.completed, 0);
    expect(after.completionRate, 0.0);
  });

  test('creation and completion days are both inclusive', () {
    final progress = _october2026(
      completed: [
        _challenge(
          'short',
          createdAt: DateTime(2026, 10, 5, 23, 59),
          completedAt: DateTime(2026, 10, 7, 0, 1),
        ),
      ],
    );

    expect(_on(progress, 4).total, 0);
    expect(_on(progress, 5).total, 1);
    expect(_on(progress, 6).total, 1);
    expect(_on(progress, 7).total, 1);
    expect(_on(progress, 8).total, 0);
    expect(progress.map((entry) => entry.completed).reduce((a, b) => a + b), 1);
    expect(_on(progress, 7).completed, 1);
    expect(_on(progress, 7).completionRate, 1.0);
  });

  test('a challenge created and completed the same day counts once', () {
    final progress = _october2026(
      completed: [
        _challenge(
          'flash',
          createdAt: DateTime(2026, 10, 12, 8),
          completedAt: DateTime(2026, 10, 12, 20),
        ),
      ],
    );

    expect(_on(progress, 11).total, 0);
    expect(_on(progress, 12).total, 1);
    expect(_on(progress, 12).completed, 1);
    expect(_on(progress, 13).total, 0);
  });

  test('no eligible challenge has no rate while 0 of N is a real 0%', () {
    final progress = _october2026(
      active: [_challenge('later', createdAt: DateTime(2026, 10, 10))],
    );

    final before = _on(progress, 9);
    expect(before.total, 0);
    expect(before.completed, 0);
    expect(before.completionRate, isNull);

    final during = _on(progress, 10);
    expect(during.total, 1);
    expect(during.completed, 0);
    expect(during.completionRate, 0.0);
  });

  test('days after today have no challenge and no rate', () {
    final progress = _october2026(
      today: CivilDay(2026, 10, 15),
      active: [_challenge('ongoing', createdAt: DateTime(2026, 10, 1))],
      completed: [
        _challenge(
          'planned',
          createdAt: DateTime(2026, 10, 1),
          completedAt: DateTime(2026, 10, 20),
        ),
      ],
    );

    expect(_on(progress, 15).total, 2);
    for (final entry in progress.where((entry) => entry.day.day > 15)) {
      expect(entry.total, 0);
      expect(entry.completed, 0);
      expect(entry.completionRate, isNull);
    }
  });

  test('an id present in both lists is counted once as completed', () {
    final progress = _october2026(
      active: [
        _challenge('same', createdAt: DateTime(2026, 10, 1)),
        _challenge('same', createdAt: DateTime(2026, 10, 1)),
      ],
      completed: [
        _challenge(
          'same',
          createdAt: DateTime(2026, 10, 1),
          completedAt: DateTime(2026, 10, 10),
        ),
      ],
    );

    expect(_on(progress, 10).total, 1);
    expect(_on(progress, 10).completed, 1);
    expect(_on(progress, 11).total, 0);
    expect(_on(progress, 11).completionRate, isNull);
  });

  test('duplicate active ids are counted once', () {
    final progress = _october2026(
      active: [
        _challenge('same', createdAt: DateTime(2026, 10, 1)),
        _challenge('same', createdAt: DateTime(2026, 10, 1)),
      ],
    );

    expect(_on(progress, 20).total, 1);
  });

  test('a completed challenge without completion date has no history', () {
    final progress = _october2026(
      active: [_challenge('duplicate', createdAt: DateTime(2026, 10, 1))],
      completed: [
        _challenge(
          'undated',
          createdAt: DateTime(2026, 10, 1),
          status: 'COMPLETED',
          updatedAt: DateTime(2026, 10, 12),
        ),
        _challenge(
          'duplicate',
          createdAt: DateTime(2026, 10, 1),
          status: 'COMPLETED',
          updatedAt: DateTime(2026, 10, 12),
        ),
      ],
    );

    for (final entry in progress) {
      expect(entry.total, 0);
      expect(entry.completed, 0);
      expect(entry.completionRate, isNull);
    }
  });

  test('inconsistent dates and non-active status add no history', () {
    final progress = _october2026(
      active: [
        _challenge(
          'proposal',
          createdAt: DateTime(2026, 10, 1),
          status: 'PENDING',
        ),
      ],
      completed: [
        _challenge(
          'time-travel',
          createdAt: DateTime(2026, 10, 10),
          completedAt: DateTime(2026, 10, 5),
        ),
      ],
    );

    expect(progress.every((entry) => entry.total == 0), isTrue);
    expect(progress.every((entry) => entry.completed == 0), isTrue);
  });

  test('local civil days decide the month boundaries', () {
    final active = [
      _challenge('night', createdAt: DateTime(2026, 9, 30, 23, 59, 59)),
    ];
    final finished = [
      _challenge(
        'midnight',
        createdAt: DateTime(2026, 10, 1, 0, 0),
        completedAt: DateTime(2026, 10, 31, 23, 59, 59),
      ),
    ];

    final september = buildGardenProgress(
      today: CivilDay(2026, 10, 31),
      month: CivilMonth(2026, 9),
      activeChallenges: active,
      completedChallenges: finished,
    );
    expect(_on(september, 29).total, 0);
    expect(_on(september, 30).total, 1);

    final october = _october2026(active: active, completed: finished);
    expect(_on(october, 1).total, 2);
    expect(_on(october, 31).total, 2);
    expect(_on(october, 31).completed, 1);

    final november = buildGardenProgress(
      today: CivilDay(2026, 11, 30),
      month: CivilMonth(2026, 11),
      activeChallenges: active,
      completedChallenges: finished,
    );
    expect(november.every((entry) => entry.total == 1), isTrue);
    expect(november.every((entry) => entry.completed == 0), isTrue);
  });

  test('months before every record and after every completion stay empty', () {
    final progress = buildGardenProgress(
      today: CivilDay(2026, 12, 31),
      month: CivilMonth(2026, 8),
      activeChallenges: [
        _challenge('recent', createdAt: DateTime(2026, 10, 1)),
      ],
      completedChallenges: [
        _challenge(
          'old',
          createdAt: DateTime(2026, 9, 1),
          completedAt: DateTime(2026, 9, 2),
        ),
      ],
    );
    expect(progress.every((entry) => entry.total == 0), isTrue);

    final december = buildGardenProgress(
      today: CivilDay(2026, 12, 31),
      month: CivilMonth(2026, 12),
      activeChallenges: const [],
      completedChallenges: [
        _challenge(
          'old',
          createdAt: DateTime(2026, 9, 1),
          completedAt: DateTime(2026, 9, 2),
        ),
      ],
    );
    expect(december.every((entry) => entry.total == 0), isTrue);
  });
}
