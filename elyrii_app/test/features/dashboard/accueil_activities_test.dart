import 'package:elyrii_app/core/storage/content_cipher.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/dashboard/data/accueil_activities.dart';
import 'package:elyrii_app/features/dashboard/domain/civil_day.dart';
import 'package:elyrii_app/features/dashboard/presentation/mood_presentation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ContentCipher cipher;
  late AccueilActivities store;
  final now = DateTime(2026, 10, 22, 19, 46);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = SecureStorageService();
    cipher = ContentCipher(storage);
    store = AccueilActivities(cipher: cipher, now: () => now);
    addTearDown(store.dispose);
  });

  test(
    'les commandes sont idempotentes et gardent la première heure',
    () async {
      store.onUserChanged(userId: 'alice');
      final day = CivilDay(2026, 10, 22);
      expect(
        await store.setRitualDone(
          day: day,
          ritual: AccueilRitual.breathe,
          done: true,
        ),
        isTrue,
      );
      final firstAt =
          store.snapshot.rituals[day]!.completedAt[AccueilRitual.breathe]!;
      expect(
        await store.setRitualDone(
          day: day,
          ritual: AccueilRitual.breathe,
          done: true,
        ),
        isTrue,
      );
      expect(
        store.snapshot.rituals[day]!.completedAt[AccueilRitual.breathe],
        firstAt,
      );
      expect(await store.completeSocialStep(day: day), isTrue);
      expect(await store.completeSocialStep(day: day), isTrue);
      final week = store.snapshot.socialWeeks[CivilDay(2026, 10, 19)]!;
      expect(week.completedAt, hasLength(1));
      expect(
        await store.answerThread(entryId: 'e1', reply: ThreadReply.ratherGood),
        isTrue,
      );
      expect(
        await store.answerThread(entryId: 'e1', reply: ThreadReply.notGreat),
        isTrue,
      );
      expect(store.snapshot.threadAnswers['e1']!.reply, ThreadReply.ratherGood);
    },
  );

  test(
    'les humeurs du jour se réenregistrent localement à chaque sélection',
    () async {
      store.onUserChanged(userId: 'alice');
      final day = CivilDay(2026, 10, 22);
      await store.recordMood(day: day, mood: MoodType.happy);
      await store.recordMood(day: day, mood: MoodType.neutral);
      expect(store.snapshot.moodDays[day], MoodType.neutral);
    },
  );

  test(
    'les faits sont isolés par compte et restaurent après rechargement',
    () async {
      store.onUserChanged(userId: 'alice');
      await store.setRitualDone(
        day: CivilDay(2026, 10, 22),
        ritual: AccueilRitual.gratitude,
        done: true,
      );
      final saved = (await SharedPreferences.getInstance()).getString(
        'accueil_activities_alice',
      );
      expect(saved, isNotNull);

      final reloaded = AccueilActivities(cipher: cipher, now: () => now);
      addTearDown(reloaded.dispose);
      reloaded.onUserChanged(userId: 'alice');
      await Future<void>.delayed(Duration.zero);
      expect(
        reloaded.snapshot.rituals[CivilDay(2026, 10, 22)]!.isDone(
          AccueilRitual.gratitude,
        ),
        isTrue,
      );

      reloaded.onUserChanged(userId: 'bob');
      await Future<void>.delayed(Duration.zero);
      expect(reloaded.snapshot.rituals, isEmpty);
      expect(
        (await SharedPreferences.getInstance()).containsKey(
          'accueil_activities_bob',
        ),
        isFalse,
      );
    },
  );

  test(
    'la question du Journal reste par compte et se réinitialise chaque jour',
    () async {
      final day = CivilDay(2026, 10, 22);
      store.onUserChanged(userId: 'alice');
      await Future<void>.delayed(Duration.zero);
      await store.nextJournalQuestion(day: day, count: 3);
      await store.nextJournalQuestion(day: day, count: 3);
      expect(store.snapshot.journalQuestionIndex(day, 3), 2);
      await store.reload();
      expect(store.snapshot.journalQuestionIndex(day, 3), 2);
      expect(store.snapshot.journalQuestionIndex(day.addDays(1), 3), 1);
      store.onUserChanged(userId: 'bob');
      await Future<void>.delayed(Duration.zero);
      expect(store.snapshot.journalQuestion, isNull);
      expect(store.snapshot.journalQuestionIndex(day, 3), 0);
    },
  );

  test('les jours de plus de 370 jours sont élagués, pas mis à zéro', () async {
    store.onUserChanged(userId: 'alice');
    final old = CivilDay(2024, 1, 2);
    await store.setRitualDone(day: old, ritual: AccueilRitual.walk, done: true);
    await store.recordMood(day: old, mood: MoodType.sad);
    final kept = CivilDay(2026, 10, 21);
    await store.setRitualDone(
      day: kept,
      ritual: AccueilRitual.walk,
      done: true,
    );
    expect(store.snapshot.rituals.containsKey(old), isFalse);
    expect(store.snapshot.moodDays.containsKey(old), isFalse);
    expect(store.snapshot.rituals[kept]!.isDone(AccueilRitual.walk), isTrue);
  });

  test(
    'un document illisible remonte une erreur au lieu d’un état vide',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('accueil_activities_carol', 'not-encrypted');
      store.onUserChanged(userId: 'carol');
      await Future<void>.delayed(Duration.zero);
      expect(store.snapshot.isLoading, isFalse);
      expect(store.snapshot.error, isNotNull);
      expect(store.snapshot.rituals, isEmpty);
    },
  );

  test('le décor absent ou inconnu revient à Arches', () {
    expect(AccueilActivities.parseDecor(null), MascotDecor.arches);
    expect(AccueilActivities.parseDecor('volcan'), MascotDecor.arches);
    expect(AccueilActivities.parseDecor('hills'), MascotDecor.hills);
  });

  test('la Clairière reste verrouillée avant dix défis terminés', () async {
    store.onUserChanged(userId: 'alice');
    await Future<void>.delayed(Duration.zero);
    expect(store.snapshot.decor, MascotDecor.arches);
    expect(
      await store.setDecor(MascotDecor.clearing, completedChallenges: 9),
      isFalse,
    );
    expect(store.snapshot.decor, MascotDecor.arches);
    expect(
      await store.setDecor(MascotDecor.clearing, completedChallenges: 10),
      isTrue,
    );
    expect(store.snapshot.decor, MascotDecor.clearing);

    final reloaded = AccueilActivities(cipher: cipher, now: () => now);
    addTearDown(reloaded.dispose);
    reloaded.onUserChanged(userId: 'alice');
    await Future<void>.delayed(Duration.zero);
    expect(reloaded.snapshot.decor, MascotDecor.clearing);
    reloaded.onUserChanged(userId: 'bob');
    await Future<void>.delayed(Duration.zero);
    expect(reloaded.snapshot.decor, MascotDecor.arches);
  });

  test('les idées du Jardin et leurs heures sont isolées par compte', () async {
    store.onUserChanged(userId: 'alice');
    await store.reload();
    expect(await store.addRitual(AccueilRitual.reachOut), isTrue);
    expect(await store.addRitual(AccueilRitual.reachOut), isTrue);
    final day = CivilDay.fromLocal(now);
    await store.setRitualDone(
      day: day,
      ritual: AccueilRitual.reachOut,
      done: true,
    );
    await store.reload();
    expect(store.snapshot.addedRituals, {AccueilRitual.reachOut});
    expect(
      store.snapshot.rituals[day]!.completedAt[AccueilRitual.reachOut],
      now.toUtc(),
    );
    store.onUserChanged(userId: 'bob');
    await store.reload();
    expect(store.snapshot.addedRituals, isEmpty);
    expect(store.snapshot.rituals, isEmpty);
    store.onUserChanged(userId: 'alice');
    await store.reload();
    expect(store.snapshot.addedRituals, {AccueilRitual.reachOut});
  });
}
