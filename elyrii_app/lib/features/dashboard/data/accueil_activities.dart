import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/storage/content_cipher.dart';
import '../domain/civil_day.dart';
import '../presentation/mood_presentation.dart';

/// Les rituels partagés entre l'Accueil et le Jardin.
enum AccueilRitual { breathe, gratitude, walk, reachOut, water, music }

/// Réponse typée au fil ; la première réponse confirmée est conservée.
enum ThreadReply { ratherGood, notGreat }

/// Le décor de la scène d'Accueil. Il vit dans ce store et non dans le look
/// de la mascotte : le serveur remplace ce look à chaque chargement et
/// retire les clés qu'il ne connaît pas.
enum MascotDecor { arches, hills, waves, clearing }

/// Règles de déblocage des décors, partagées par le dressing et le store.
abstract final class MascotDecorRules {
  /// La Clairière s'obtient avec dix défis terminés, les fleurs du Jardin.
  static const clearingChallenges = 10;

  static int requiredChallenges(MascotDecor decor) =>
      decor == MascotDecor.clearing ? clearingChallenges : 0;

  static bool isUnlocked(MascotDecor decor, int completedChallenges) =>
      completedChallenges >= requiredChallenges(decor);
}

/// Rituels réalisés un jour donné, avec l'heure de chaque réalisation.
class RitualDay {
  final CivilDay day;
  final Map<AccueilRitual, DateTime> completedAt;

  RitualDay({required this.day, required this.completedAt});

  bool isDone(AccueilRitual ritual) => completedAt.containsKey(ritual);
}

/// Pas sociaux d'une semaine ISO, ancrée sur son lundi réel.
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

/// Une réponse au fil, rattachée à l'identifiant de l'entrée de Journal.
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

/// The Journal question the user picked with « Changer la question ».
class JournalQuestionPick {
  final CivilDay day;
  final int index;
  const JournalQuestionPick({required this.day, required this.index});
}

/// Photographie gelée des faits locaux d'Accueil. Une lecture manquante
/// reste `isLoading` ou porte une erreur : aucun zéro de complaisance.
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

/// Faits locaux mutables, copiés depuis une photographie puis regelés.
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

/// Seul propriétaire des faits locaux d'Accueil : rituels cochés, pas
/// sociaux, réponses au fil, humeurs notées sur cet appareil, décor et
/// question du Journal choisie pour le jour.
///
/// Le document est chiffré par compte (`accueil-activities:v1`), jamais
/// synchronisé au serveur, et les jours de plus de 370 jours sont élagués :
/// un jour élagué redevient inconnu, jamais zéro. Les écritures passent par
/// une seule file ; une erreur restaure la photographie confirmée et
/// remonte l'erreur au lieu de la masquer.
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

  /// Toutes les écritures acceptées se terminent, même après un changement
  /// de compte ou une suppression.
  Future<void> get flushed => _writes;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Change de compte : l'ancienne lecture est invalidée avant le premier
  /// `await`, la nouvelle photographie démarre en chargement.
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

  /// Un décor absent ou inconnu redevient Arches, sans jamais débloquer une
  /// récompense.
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

  /// État souhaité d'un rituel. Cocher deux fois garde la première heure ;
  /// décocher puis recocher constitue une nouvelle réalisation.
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

  /// Répond au fil : la première réponse confirmée d'une entrée est gardée.
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

  /// Un pas social au plus par date ; un second clic le même jour garde le
  /// premier horodatage.
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

  /// Passe à l'idée sociale suivante de la semaine, sans toucher au compteur.
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

  /// Note l'humeur confirmée ce jour-là. La dernière humeur du jour gagne.
  Future<bool> recordMood({required CivilDay day, required MoodType mood}) {
    final facts = _Facts.of(_snapshot);
    if (facts.moodDays[day] == mood) return Future.value(true);
    facts.moodDays[day] = mood;
    return _commit(facts);
  }

  /// Change le décor. Un décor verrouillé est refusé sans écriture ; le
  /// dressing n'appelle cette commande qu'après l'enregistrement du look.
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

  /// Le lundi de la semaine ISO de [day], clé des pas sociaux.
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

  /// Élague les faits trop vieux : 370 jours de rétention, 50 réponses.
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

  /// Retire le document d'un compte supprimé, après les écritures en cours.
  Future<void> deleteOwner(String userId) async {
    await _writes;
    final prefs = await _prefs;
    await prefs.remove('accueil_activities_$userId');
  }
}
