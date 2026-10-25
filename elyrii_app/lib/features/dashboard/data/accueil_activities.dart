import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/storage/content_cipher.dart';
import '../domain/civil_day.dart';
import '../presentation/mood_presentation.dart';

/// Rituals shared by Home and Garden.
enum AccueilRitual { breathe, gratitude, walk, reachOut, water, music }

/// Typed follow-up response; the first confirmed answer is retained.
enum ThreadReply { ratherGood, notGreat }

/// Home scene background. It lives in this store rather than the mascot look
/// because the server replaces that look on every load and removes unknown
/// keys.
enum MascotDecor { arches, hills, waves, clearing }

/// Scene unlock rules shared by the dressing room and store.
abstract final class MascotDecorRules {
  /// Clearing unlocks after ten completed challenges, represented by Garden
  /// flowers.
  static const clearingChallenges = 10;

  static int requiredChallenges(MascotDecor decor) =>
      decor == MascotDecor.clearing ? clearingChallenges : 0;

  static bool isUnlocked(MascotDecor decor, int completedChallenges) =>
      completedChallenges >= requiredChallenges(decor);
}

/// Rituals completed on a given day, with each completion time.
class RitualDay {
  final CivilDay day;
  final Map<AccueilRitual, DateTime> completedAt;

  RitualDay({required this.day, required this.completedAt});

  bool isDone(AccueilRitual ritual) => completedAt.containsKey(ritual);
}

/// Social steps for an ISO week, anchored to its actual Monday.
class SocialWeek {
  final CivilDay monday;
  final int ideaIndex;
  final Map<CivilDay, DateTime> completedAt;

  SocialWeek({
    required this.monday,
    required this.ideaIndex,
    required this.completedAt,
  });

  bool isDone(CivilDay day) => completedAt.containsKey(day);
}

/// Follow-up answer attached to a journal entry ID.
class ThreadAnswer {
  final String entryId;
  final ThreadReply reply;
  final DateTime answeredAt;

  const ThreadAnswer({
    required this.entryId,
    required this.reply,
    required this.answeredAt,
  });
}

/// The Journal question explicitly selected by the user.
class JournalQuestionPick {
  final CivilDay day;
  final int index;
  const JournalQuestionPick({required this.day, required this.index});
}

/// Frozen snapshot of local Home facts. Missing reads stay `isLoading` or carry
/// an error rather than substituting zero.
class AccueilActivitySnapshot {
  final Map<CivilDay, RitualDay> rituals;
  final Map<CivilDay, SocialWeek> socialWeeks;
  final Map<String, ThreadAnswer> threadAnswers;
  final Map<CivilDay, MoodType> moodDays;
  final MascotDecor decor;
  final Set<AccueilRitual> addedRituals;
  final JournalQuestionPick? journalQuestion;
  final bool isLoading;
  final bool isWriting;
  final String? error;

  AccueilActivitySnapshot({
    Map<CivilDay, RitualDay>? rituals,
    Map<CivilDay, SocialWeek>? socialWeeks,
    Map<String, ThreadAnswer>? threadAnswers,
    Map<CivilDay, MoodType>? moodDays,
    this.decor = MascotDecor.arches,
    Set<AccueilRitual>? addedRituals,
    this.journalQuestion,
    this.isLoading = false,
    this.isWriting = false,
    this.error,
  }) : addedRituals = Set.unmodifiable(addedRituals ?? const {}),
       rituals = Map.unmodifiable(rituals ?? const {}),
       socialWeeks = Map.unmodifiable(socialWeeks ?? const {}),
       threadAnswers = Map.unmodifiable(threadAnswers ?? const {}),
       moodDays = Map.unmodifiable(moodDays ?? const {});

  /// The question shown on [day]: the user's pick of that day, otherwise
  /// a rotation derived from the date.
  int journalQuestionIndex(CivilDay day, int count) {
    final pick = journalQuestion;
    if (pick != null && pick.day == day) return pick.index % count;
    return CivilDay(1970, 1, 1).daysUntil(day) % count;
  }
}

/// Mutable local facts copied from a snapshot before being frozen again.
class _Facts {
  final Map<CivilDay, RitualDay> rituals = {};
  final Map<CivilDay, SocialWeek> socialWeeks = {};
  final Map<String, ThreadAnswer> threadAnswers = {};
  final Map<CivilDay, MoodType> moodDays = {};
  MascotDecor decor = MascotDecor.arches;
  final Set<AccueilRitual> addedRituals = {};
  JournalQuestionPick? journalQuestion;

  _Facts();

  _Facts.of(AccueilActivitySnapshot snapshot) {
    for (final entry in snapshot.rituals.entries) {
      rituals[entry.key] = RitualDay(
        day: entry.value.day,
        completedAt: Map.of(entry.value.completedAt),
      );
    }
    for (final entry in snapshot.socialWeeks.entries) {
      socialWeeks[entry.key] = SocialWeek(
        monday: entry.value.monday,
        ideaIndex: entry.value.ideaIndex,
        completedAt: Map.of(entry.value.completedAt),
      );
    }
    threadAnswers.addAll(snapshot.threadAnswers);
    moodDays.addAll(snapshot.moodDays);
    decor = snapshot.decor;
    addedRituals.addAll(snapshot.addedRituals);
    journalQuestion = snapshot.journalQuestion;
  }

  AccueilActivitySnapshot snapshot({bool isWriting = false, String? error}) =>
      AccueilActivitySnapshot(
        rituals: rituals,
        socialWeeks: socialWeeks,
        threadAnswers: threadAnswers,
        moodDays: moodDays,
        decor: decor,
        addedRituals: addedRituals,
        journalQuestion: journalQuestion,
        isWriting: isWriting,
        error: error,
      );
}

/// Sole owner of local Home facts: checked rituals, social steps, follow-up
/// answers, device-recorded moods, scene, and the day's selected Journal
/// question. The account-scoped document is encrypted with
/// `accueil-activities:v1` and never synchronized to the server. Days older
/// than 370 days are pruned and become unknown rather than zero. Writes use one
/// queue; failures restore the confirmed snapshot and surface the error.
class AccueilActivities extends ChangeNotifier {
  static const _documentVersion = 1;
  static const _purpose = 'accueil-activities:v1';
  static const _retentionDays = 370;
  static const _maxThreadAnswers = 50;

  final ContentCipher cipher;
  final SharedPreferences? preferences;
  final DateTime Function() now;

  AccueilActivities({
    required this.cipher,
    this.preferences,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  String _scope = 'guest';
  int _revision = 0;
  bool _disposed = false;
  AccueilActivitySnapshot _snapshot = AccueilActivitySnapshot(isLoading: true);
  Future<void> _writes = Future.value();

  AccueilActivitySnapshot get snapshot => _snapshot;

  /// All accepted writes finish, even after an account change or deletion.
  Future<void> get flushed => _writes;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Switches accounts: invalidates the old read before the first `await` and
  /// starts the new snapshot in a loading state.
  void onUserChanged({String? userId, bool isDemo = false}) {
    _revision++;
    _scope = isDemo ? 'demo' : userId ?? 'guest';
    _snapshot = AccueilActivitySnapshot(isLoading: true);
    _notify();
    unawaited(_load(_revision));
  }

  Future<void> reload() async {
    if (_snapshot.isWriting) return;
    _revision++;
    _snapshot = AccueilActivitySnapshot(isLoading: true);
    _notify();
    await _load(_revision);
  }

  Future<SharedPreferences> get _prefs async =>
      preferences ?? await SharedPreferences.getInstance();

  String get _key => 'accueil_activities_$_scope';

  Future<void> _load(int revision) async {
    try {
      final prefs = await _prefs;
      final raw = prefs.getString(_key);
      if (raw == null) {
        _publishIfCurrent(revision, _Facts().snapshot());
        return;
      }
      final clear = await cipher.open(_scope, raw, purpose: _purpose);
      final document = jsonDecode(clear) as Map<String, dynamic>;
      if (document['version'] != _documentVersion) {
        throw const FormatException('Unsupported accueil activities version');
      }
      if (document['owner'] != _scope) {
        throw const FormatException('Accueil activities account mismatch');
      }
      final facts = _Facts()
        ..rituals.addAll(_parseRituals(document['ritualDays']))
        ..socialWeeks.addAll(_parseSocialWeeks(document['socialWeeks']))
        ..threadAnswers.addAll(_parseThreadAnswers(document['threadAnswers']))
        ..moodDays.addAll(_parseMoodDays(document['moodDays']))
        ..decor = parseDecor(document['decor'])
        ..journalQuestion = _parseJournalQuestion(document['journalQuestion']);
      final added = document['addedRituals'];
      if (added is List) {
        facts.addedRituals.addAll(
          AccueilRitual.values.where((ritual) => added.contains(ritual.name)),
        );
      }
      _publishIfCurrent(revision, facts.snapshot());
    } catch (_) {
      // Des données corrompues ne deviennent jamais un document vide :
      // l'erreur est visible et le reste de l'Accueil reste utilisable.
      if (!_disposed && revision == _revision) {
        _snapshot = AccueilActivitySnapshot(
          error: 'Tes activités locales n’ont pas pu être lues.',
        );
        _notify();
      }
    }
  }

  void _publishIfCurrent(int revision, AccueilActivitySnapshot snapshot) {
    if (_disposed || revision != _revision) return;
    _snapshot = snapshot;
    _notify();
  }

  /// Missing or unknown scenes fall back to Arches without unlocking rewards.
  @visibleForTesting
  static MascotDecor parseDecor(dynamic raw) =>
      MascotDecor.values.where((value) => value.name == raw).firstOrNull ??
      MascotDecor.arches;

  Map<CivilDay, RitualDay> _parseRituals(dynamic raw) {
    final days = <CivilDay, RitualDay>{};
    if (raw is! Map) return days;
    for (final entry in raw.entries) {
      final day = CivilDay.tryParse(entry.key as String? ?? '');
      final value = entry.value;
      if (day == null || value is! Map) continue;
      final completedAt = <AccueilRitual, DateTime>{};
      for (final done in value.entries) {
        final ritual = AccueilRitual.values
            .where((ritual) => ritual.name == done.key)
            .firstOrNull;
        final at = DateTime.tryParse(done.value as String? ?? '');
        if (ritual != null && at != null) completedAt[ritual] = at.toUtc();
      }
      days[day] = RitualDay(day: day, completedAt: completedAt);
    }
    return days;
  }

  Map<CivilDay, SocialWeek> _parseSocialWeeks(dynamic raw) {
    final weeks = <CivilDay, SocialWeek>{};
    if (raw is! Map) return weeks;
    for (final entry in raw.entries) {
      final monday = CivilDay.tryParse(entry.key as String? ?? '');
      final value = entry.value;
      if (monday == null || value is! Map) continue;
      final completedAt = <CivilDay, DateTime>{};
      final rawDone = value['completedAt'];
      if (rawDone is Map) {
        for (final done in rawDone.entries) {
          final day = CivilDay.tryParse(done.key as String? ?? '');
          final at = DateTime.tryParse(done.value as String? ?? '');
          if (day != null && at != null) completedAt[day] = at.toUtc();
        }
      }
      weeks[monday] = SocialWeek(
        monday: monday,
        ideaIndex: value['ideaIndex'] as int? ?? 0,
        completedAt: completedAt,
      );
    }
    return weeks;
  }

  Map<String, ThreadAnswer> _parseThreadAnswers(dynamic raw) {
    final answers = <String, ThreadAnswer>{};
    if (raw is! Map) return answers;
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      final reply = ThreadReply.values
          .where((reply) => reply.name == value['reply'])
          .firstOrNull;
      final at = DateTime.tryParse(value['answeredAt'] as String? ?? '');
      if (reply == null || at == null) continue;
      answers[entry.key as String] = ThreadAnswer(
        entryId: entry.key as String,
        reply: reply,
        answeredAt: at.toUtc(),
      );
    }
    return answers;
  }

  Map<CivilDay, MoodType> _parseMoodDays(dynamic raw) {
    final moods = <CivilDay, MoodType>{};
    if (raw is! Map) return moods;
    for (final entry in raw.entries) {
      final day = CivilDay.tryParse(entry.key as String? ?? '');
      final mood = MoodType.values
          .where((mood) => mood.name == entry.value)
          .firstOrNull;
      if (day != null && mood != null) moods[day] = mood;
    }
    return moods;
  }

  JournalQuestionPick? _parseJournalQuestion(dynamic raw) {
    if (raw is! Map) return null;
    final day = CivilDay.tryParse(raw['day'] as String? ?? '');
    final index = raw['index'];
    if (day == null || index is! int || index < 0) return null;
    return JournalQuestionPick(day: day, index: index);
  }

  /// Desired ritual state. Checking twice keeps the first time; unchecking and
  /// checking again creates a new completion.
  Future<bool> setRitualDone({
    required CivilDay day,
    required AccueilRitual ritual,
    required bool done,
  }) {
    final facts = _Facts.of(_snapshot);
    final ritualDay =
        facts.rituals[day] ?? RitualDay(day: day, completedAt: {});
    if (done == ritualDay.isDone(ritual)) return Future.value(true);
    final completedAt = Map<AccueilRitual, DateTime>.from(
      ritualDay.completedAt,
    );
    if (done) {
      completedAt[ritual] = now().toUtc();
    } else {
      completedAt.remove(ritual);
    }
    facts.rituals[day] = RitualDay(day: day, completedAt: completedAt);
    return _commit(facts);
  }

  Future<bool> addRitual(AccueilRitual ritual) {
    if (_snapshot.isLoading || _snapshot.isWriting || _snapshot.error != null) {
      return Future.value(false);
    }
    if (_snapshot.addedRituals.contains(ritual)) return Future.value(true);
    final facts = _Facts.of(_snapshot)..addedRituals.add(ritual);
    return _commit(facts);
  }

  /// Answers a follow-up, retaining the entry's first confirmed answer.
  Future<bool> answerThread({
    required String entryId,
    required ThreadReply reply,
  }) {
    if (entryId.isEmpty) return Future.value(false);
    final facts = _Facts.of(_snapshot);
    if (facts.threadAnswers.containsKey(entryId)) return Future.value(true);
    facts.threadAnswers[entryId] = ThreadAnswer(
      entryId: entryId,
      reply: reply,
      answeredAt: now().toUtc(),
    );
    return _commit(facts);
  }

  /// At most one social step per date; another click that day keeps the first
  /// timestamp.
  Future<bool> completeSocialStep({required CivilDay day}) {
    final monday = mondayOf(day);
    final facts = _Facts.of(_snapshot);
    final week =
        facts.socialWeeks[monday] ??
        SocialWeek(monday: monday, ideaIndex: 0, completedAt: {});
    if (week.isDone(day)) return Future.value(true);
    final completedAt = Map<CivilDay, DateTime>.from(week.completedAt);
    completedAt[day] = now().toUtc();
    facts.socialWeeks[monday] = SocialWeek(
      monday: monday,
      ideaIndex: week.ideaIndex,
      completedAt: completedAt,
    );
    return _commit(facts);
  }

  /// Advances to the week's next social idea without changing the counter.
  Future<bool> nextSocialIdea({required CivilDay day}) {
    final monday = mondayOf(day);
    final facts = _Facts.of(_snapshot);
    final week =
        facts.socialWeeks[monday] ??
        SocialWeek(monday: monday, ideaIndex: 0, completedAt: {});
    facts.socialWeeks[monday] = SocialWeek(
      monday: monday,
      ideaIndex: week.ideaIndex + 1,
      completedAt: week.completedAt,
    );
    return _commit(facts);
  }

  /// Records the day's confirmed mood; the last mood that day wins.
  Future<bool> recordMood({required CivilDay day, required MoodType mood}) {
    final facts = _Facts.of(_snapshot);
    if (facts.moodDays[day] == mood) return Future.value(true);
    facts.moodDays[day] = mood;
    return _commit(facts);
  }

  /// Changes the scene. Locked scenes are rejected without writing; the
  /// dressing room calls this only after saving the look.
  Future<bool> setDecor(MascotDecor decor, {required int completedChallenges}) {
    if (!MascotDecorRules.isUnlocked(decor, completedChallenges)) {
      return Future.value(false);
    }
    final facts = _Facts.of(_snapshot);
    if (facts.decor == decor) return Future.value(true);
    facts.decor = decor;
    return _commit(facts);
  }

  /// Shows the next Journal question for [day], among [count] questions.
  Future<bool> nextJournalQuestion({
    required CivilDay day,
    required int count,
  }) {
    final facts = _Facts.of(_snapshot);
    facts.journalQuestion = JournalQuestionPick(
      day: day,
      index: (_snapshot.journalQuestionIndex(day, count) + 1) % count,
    );
    return _commit(facts);
  }

  /// Monday of [day]'s ISO week, used as the social-step key.
  static CivilDay mondayOf(CivilDay day) => day.addDays(-(day.weekday - 1));

  void _capThreadAnswers(Map<String, ThreadAnswer> answers) {
    if (answers.length <= _maxThreadAnswers) return;
    final ordered = answers.values.toList()
      ..sort((a, b) => a.answeredAt.compareTo(b.answeredAt));
    for (final stale in ordered.take(answers.length - _maxThreadAnswers)) {
      answers.remove(stale.entryId);
    }
  }

  Map<String, dynamic> _document(_Facts facts) {
    return {
      'version': _documentVersion,
      'owner': _scope,
      'ritualDays': {
        for (final entry in facts.rituals.entries)
          entry.key.isoDate: {
            for (final done in entry.value.completedAt.entries)
              done.key.name: done.value.toIso8601String(),
          },
      },
      'socialWeeks': {
        for (final entry in facts.socialWeeks.entries)
          entry.key.isoDate: {
            'ideaIndex': entry.value.ideaIndex,
            'completedAt': {
              for (final done in entry.value.completedAt.entries)
                done.key.isoDate: done.value.toIso8601String(),
            },
          },
      },
      'threadAnswers': {
        for (final entry in facts.threadAnswers.entries)
          entry.key: {
            'reply': entry.value.reply.name,
            'answeredAt': entry.value.answeredAt.toIso8601String(),
          },
      },
      'moodDays': {
        for (final entry in facts.moodDays.entries)
          entry.key.isoDate: entry.value.name,
      },
      'decor': facts.decor.name,
      'addedRituals': facts.addedRituals.map((ritual) => ritual.name).toList(),
      if (facts.journalQuestion case final pick?)
        'journalQuestion': {'day': pick.day.isoDate, 'index': pick.index},
    };
  }

  /// Prunes old facts: 370-day retention and 50 answers.
  void _prune(_Facts facts) {
    final cutoff = CivilDay.fromLocal(now()).addDays(-_retentionDays);
    facts.rituals.removeWhere((day, _) => day.isBefore(cutoff));
    facts.socialWeeks.removeWhere((monday, _) => monday.isBefore(cutoff));
    facts.moodDays.removeWhere((day, _) => day.isBefore(cutoff));
    _capThreadAnswers(facts.threadAnswers);
  }

  Future<bool> _commit(_Facts facts) async {
    if (_disposed) return false;
    final revision = _revision;
    final scope = _scope;
    final key = _key;
    _prune(facts);
    final confirmed = _Facts.of(_snapshot);
    _snapshot = facts.snapshot(isWriting: true);
    _notify();
    final write = _writes.then((_) async {
      final encrypted = await cipher.seal(
        scope,
        jsonEncode(_document(facts)),
        purpose: _purpose,
      );
      final prefs = await _prefs;
      if (!await prefs.setString(key, encrypted)) {
        throw StateError('Accueil activities write refused');
      }
    });
    _writes = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    try {
      await write;
    } catch (_) {
      // Le document confirmé survit à l'échec ; l'erreur est visible et la
      // commande peut être rejouée.
      if (!_disposed && revision == _revision) {
        _snapshot = confirmed.snapshot(
          error: 'Ton changement n’a pas été enregistré. Réessaie.',
        );
        _notify();
      }
      return false;
    }
    if (!_disposed && revision == _revision) {
      _snapshot = facts.snapshot();
      _notify();
    }
    return revision == _revision;
  }

  /// Removes a deleted account's document after pending writes finish.
  Future<void> deleteOwner(String userId) async {
    await _writes;
    final prefs = await _prefs;
    await prefs.remove('accueil_activities_$userId');
  }
}
