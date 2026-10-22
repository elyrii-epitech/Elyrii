import 'package:elyrii_app/features/dashboard/data/accueil_activities.dart';
import 'package:elyrii_app/features/dashboard/data/models/dashboard_models.dart';
import 'package:elyrii_app/features/dashboard/domain/accueil_content.dart';
import 'package:elyrii_app/features/dashboard/domain/civil_day.dart';
import 'package:elyrii_app/features/dashboard/presentation/mood_presentation.dart';
import 'package:elyrii_app/features/gamification/data/models/gamification_models.dart';
import 'package:elyrii_app/features/journal/data/models/journal_entry_model.dart';
import 'package:flutter_test/flutter_test.dart';

ActivityTimelinePoint _point(CivilDay day, {int moods = 1, int writes = 0}) =>
    ActivityTimelinePoint(day: day, moodLogs: moods, journalEntries: writes);

UserChallenge _done(String id, DateTime? at) => UserChallenge(
  id: id,
  userId: 'alice',
  challengeId: 'c-$id',
  status: 'COMPLETED',
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
  completedAt: at,
);

JournalEntryModel _entry(
  String id,
  DateTime at, {
  String title = '',
  String? content,
}) => JournalEntryModel(
  id: id,
  userId: 'alice',
  title: title,
  content: content,
  createdAt: at,
  updatedAt: at,
);

void main() {
  final evening = DateTime(2026, 10, 22, 21);
  final today = CivilDay(2026, 10, 22);

  group('réponses et matrice d’humeur', () {
    test('le soutien passe d’abord pour Éprouvé et Vulnérable', () {
      final hard = layoutForMood(MoodType.verySad);
      expect(hard.showsRituals, isFalse);
      expect(hard.showsRest, isTrue);
      expect(hard.showsSocial, isFalse);
      final low = layoutForMood(MoodType.sad);
      expect(low.showsRituals, isFalse);
      expect(low.showsRest, isTrue);
      expect(low.showsSocial, isTrue);
      for (final mood in [
        null,
        MoodType.neutral,
        MoodType.happy,
        MoodType.veryHappy,
      ]) {
        final layout = layoutForMood(mood);
        expect(layout.showsRituals, isTrue, reason: '$mood');
        expect(layout.showsRest, isFalse, reason: '$mood');
        expect(layout.showsSocial, isTrue, reason: '$mood');
      }
    });

    test('le 3114 et le soft pink suivent la table ANSWERS', () {
      final hard = answerForMood(MoodType.verySad, evening);
      expect(hard.showsHelp, isTrue);
      expect(hard.isSoftPink, isTrue);
      expect(hard.actions.map((a) => a.action), [
        isA<OpenChat>(),
        isA<Breathe>(),
      ]);
      final low = answerForMood(MoodType.sad, evening);
      expect(low.showsHelp, isFalse);
      expect(low.isSoftPink, isTrue);
      for (final mood in [
        null,
        MoodType.neutral,
        MoodType.happy,
        MoodType.veryHappy,
      ]) {
        expect(answerForMood(mood, evening).showsHelp, isFalse);
        expect(answerForMood(mood, evening).isSoftPink, isFalse);
      }
      expect(answerForMood(null, evening).actions, isEmpty);
      expect(
        answerForMood(MoodType.veryHappy, evening).actions.first.action,
        isA<ContactSomeone>(),
      );
    });

    test('Paisible ne propose plus de rappel coucher', () {
      final calm = answerForMood(MoodType.neutral, evening);
      expect(calm.actions.map((a) => a.label), ['Respirer 2 min']);
    });

    test('le moment de la journée remplace « ce soir »', () {
      final morning = DateTime(2026, 10, 22, 8);
      final afternoon = DateTime(2026, 10, 22, 15);
      expect(
        answerForMood(MoodType.verySad, evening).title,
        'Ça a l\'air lourd ce soir.',
      );
      expect(
        answerForMood(MoodType.verySad, morning).title,
        'Ça a l\'air lourd ce matin.',
      );
      expect(
        answerForMood(MoodType.veryHappy, afternoon).title,
        'Tu rayonnes cet après-midi !',
      );
      expect(
        answerForMood(MoodType.neutral, morning).title,
        'Un matin paisible, ça se garde.',
      );
      expect(
        answerForMood(null, evening).body,
        'Je m\'adapte à ta soirée : un geste, pas une liste.',
      );
      expect(
        answerForMood(MoodType.neutral, morning).body,
        isNot(contains('dormir')),
      );
      expect(moodQuestion(morning), 'Comment te sens-tu ce matin ?');
    });
  });

  group('calendrier', () {
    test('distingue humeur locale, présence sans humeur, absence, inconnu et futur', () {
      final month = buildCalendarMonth(
        month: CivilMonth(2026, 10),
        today: today,
        history: {
          CivilDay(2026, 10, 20): _point(CivilDay(2026, 10, 20)),
          CivilDay(2026, 10, 21): _point(
            CivilDay(2026, 10, 21),
            moods: 0,
            writes: 1,
          ),
        },
        coverage: CalendarCoverage(
          firstDay: CivilDay(2026, 10, 10),
          throughDay: today,
        ),
        activities: AccueilActivitySnapshot(
          moodDays: {
            today: MoodType.happy,
            CivilDay(2026, 10, 2): MoodType.sad,
          },
        ),
        currentStreak: 3,
      );
      CalendarCell cell(int day) => month.cells[day - 1];
      expect(month.leadingBlanks, 3); // le 1er octobre 2026 est un jeudi
      expect(cell(22).state, CalendarCellState.presentWithMood);
      expect(cell(22).mood, MoodType.happy);
      // Serveur ancien : présence connue, sans humeur locale.
      expect(cell(20).state, CalendarCellState.presentWithoutMood);
      expect(cell(21).state, CalendarCellState.presentWithoutMood);
      expect(cell(21).journalEntries, 1);
      expect(cell(15).state, CalendarCellState.absent);
      expect(cell(5).state, CalendarCellState.uncovered);
      expect(cell(2).state, CalendarCellState.presentWithMood);
      expect(cell(23).state, CalendarCellState.future);
      expect(month.elapsedDays, 22);
      expect(month.presentDays, 4);
      expect(cell(15).ritualsDone, isNull);
    });

    test('la bande de série finit aujourd’hui, ou hier, et s’arrête au premier trou', () {
      final history = {
        for (final d in [18, 19, 20, 21])
          CivilDay(2026, 10, d): _point(CivilDay(2026, 10, d)),
      };
      final coverage = CalendarCoverage(
        firstDay: CivilDay(2026, 10, 1),
        throughDay: today,
      );
      Set<int> band(Map<CivilDay, MoodType> moods, int streak) => {
        for (final cell in buildCalendarMonth(
          month: CivilMonth(2026, 10),
          today: today,
          history: history,
          coverage: coverage,
          activities: AccueilActivitySnapshot(moodDays: moods),
          currentStreak: streak,
        ).cells)
          if (cell.inStreak) cell.day.day,
      };
      expect(band({}, 10), {
        18,
        19,
        20,
        21,
      }); // aujourd'hui sans activité : fin hier
      expect(band({today: MoodType.happy}, 10), {18, 19, 20, 21, 22});
      expect(band({today: MoodType.happy}, 2), {
        21,
        22,
      }); // bornée par le serveur
      expect(band({}, 0), isEmpty);
    });

    test('la semaine Série coche les jours de la série', () {
      final week = buildStreakWeek(today: today, currentStreak: 3);
      expect(week.map((d) => d.day.weekday), [1, 2, 3, 4, 5, 6, 7]);
      expect(week.map((d) => d.state), [
        StreakDayState.missed,
        StreakDayState.done,
        StreakDayState.done,
        StreakDayState.done,
        StreakDayState.upcoming,
        StreakDayState.upcoming,
        StreakDayState.upcoming,
      ]);
      final notYet = buildStreakWeek(
        today: today,
        currentStreak: 3,
        todayCounted: false,
      );
      expect(notYet[3].state, StreakDayState.upcoming);
      expect(notYet[0].state, StreakDayState.done);
    });
  });

  group('fleurs', () {
    test(
      'une fleur par défi terminé, groupée par jour avec l’humeur du jour',
      () {
        final flowers = buildWeekFlowers(
          today: today,
          completedChallenges: [
            _done('a', DateTime(2026, 10, 20, 9)),
            _done('b', DateTime(2026, 10, 20, 18)),
            _done('b', DateTime(2026, 10, 20, 18)),
            _done('c', DateTime(2026, 10, 22, 10)),
            _done('old', DateTime(2026, 10, 18, 10)), // dimanche précédent
            _done('undated', null),
          ],
          activities: AccueilActivitySnapshot(
            moodDays: {CivilDay(2026, 10, 20): MoodType.neutral},
          ),
        );
        expect(flowers.monday, CivilDay(2026, 10, 19));
        expect(flowers.all.map((f) => f.challengeId), ['a', 'b', 'c']);
        expect(flowers.byWeekday[2]!.map((f) => f.challengeId), ['a', 'b']);
        expect(
          flowers.byWeekday[2]!.every((f) => f.mood == MoodType.neutral),
          isTrue,
        );
        expect(flowers.byWeekday[4]!.single.mood, isNull);
        expect(flowers.byWeekday[1], isEmpty);
      },
    );
  });

  group('fil', () {
    test('reprend la dernière entrée des trois derniers jours', () {
      final yesterdayEvening = DateTime(2026, 10, 21, 21);
      final thread = projectThread(
        entries: [
          _entry('old', DateTime(2026, 10, 15), title: 'Ancien'),
          _entry(
            'e1',
            yesterdayEvening,
            content: 'J\'ai peur de rater mon oral. Le reste va.',
          ),
          _entry('future', DateTime(2026, 10, 23), title: 'Futur'),
        ],
        now: evening,
        activities: AccueilActivitySnapshot(),
      );
      expect(thread!.entryId, 'e1');
      expect(thread.preamble, 'Hier soir, tu m\'as confié');
      expect(thread.quote, 'J\'ai peur de rater mon oral.');
      expect(thread.answer, isNull);
      expect(
        projectThread(
          entries: [_entry('old', DateTime(2026, 10, 15), title: 'Ancien')],
          now: evening,
          activities: AccueilActivitySnapshot(),
        ),
        isNull,
      );
    });
  });

  group('insight', () {
    test(
      'reste absente sans assez de jours, apparaît quand l’écart est étayé',
      () {
        final coverage = CalendarCoverage(
          firstDay: CivilDay(2026, 9, 1),
          throughDay: today,
        );
        Map<CivilDay, ActivityTimelinePoint> history(int journalDays) => {
          for (var i = 1; i <= 10; i++)
            CivilDay(2026, 10, i): _point(
              CivilDay(2026, 10, i),
              writes: i <= journalDays ? 1 : 0,
            ),
        };
        final moods = {
          for (var i = 1; i <= 10; i++)
            CivilDay(2026, 10, i): i <= 5 ? MoodType.veryHappy : MoodType.sad,
        };
        final insight = deriveInsight(
          history: history(5),
          coverage: coverage,
          activities: AccueilActivitySnapshot(moodDays: moods),
        );
        expect(insight, isNotNull);
        expect(insight!.journalMoodDays, 5);
        expect(insight.otherMoodDays, 5);
        expect(
          deriveInsight(
            history: history(4),
            coverage: coverage,
            activities: AccueilActivitySnapshot(moodDays: moods),
          ),
          isNull,
        );
        expect(
          deriveInsight(
            history: history(5),
            coverage: null,
            activities: AccueilActivitySnapshot(moodDays: moods),
          ),
          isNull,
        );
      },
    );
  });
}
