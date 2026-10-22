import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/storage/content_cipher.dart';
import '../domain/civil_day.dart';
import '../presentation/mood_presentation.dart';

/// Les trois rituels du jour, dans l'ordre de la grille Accueil.
enum AccueilRitual { breathe, gratitude, walk }

/// Réponse typée au fil ; la première réponse confirmée est conservée.
enum ThreadReply { ratherGood, notGreat }

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

/// Photographie gelée des faits locaux d'Accueil. Une lecture manquante
/// reste `isLoading` ou porte une erreur : aucun zéro de complaisance.
class AccueilActivitySnapshot {
  final Map<CivilDay, RitualDay> rituals;
  final Map<CivilDay, SocialWeek> socialWeeks;
  final Map<String, ThreadAnswer> threadAnswers;
  final Map<CivilDay, MoodType> moodDays;
  final bool isLoading;
  final bool isWriting;
  final String? error;

  AccueilActivitySnapshot({
    Map<CivilDay, RitualDay>? rituals,
    Map<CivilDay, SocialWeek>? socialWeeks,
    Map<String, ThreadAnswer>? threadAnswers,
    Map<CivilDay, MoodType>? moodDays,
    this.isLoading = false,
    this.isWriting = false,
    this.error,
  }) : rituals = Map.unmodifiable(rituals ?? const {}),
       socialWeeks = Map.unmodifiable(socialWeeks ?? const {}),
       threadAnswers = Map.unmodifiable(threadAnswers ?? const {}),
       moodDays = Map.unmodifiable(moodDays ?? const {});
}

/// Faits locaux mutables, copiés puis geler en photographie.
class _Facts {
  final Map<CivilDay, RitualDay> rituals = {};
  final Map<CivilDay, SocialWeek> socialWeeks = {};
  final Map<String, ThreadAnswer> threadAnswers = {};
  final Map<CivilDay, MoodType> moodDays = {};

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
  }

  AccueilActivitySnapshot snapshot({bool isWriting = false}) =>
      AccueilActivitySnapshot(
        rituals: rituals,
        socialWeeks: socialWeeks,
        threadAnswers: threadAnswers,
        moodDays: moodDays,
        isWriting: isWriting,
      );
}

/// Seul propriétaire des nouveaux faits locaux d'Accueil : rituels cochés,
/// pas sociaux, réponses au fil et humeurs notées sur cet appareil.
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
        ..moodDays.addAll(_parseMoodDays(document['moodDays']));
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

  Map<CivilDay, RitualDay> _parseRituals(dynamic raw) {
    final days = <CivilDay, RitualDay>{};
    if (raw is! Map) return days;
    for (final entry in raw.entries) {
      final day = CivilDay.tryParse(entry.key as String? ?? '');
      if (day == null || entry.value is! Map) continue;
      final completedAt = <AccueilRitual, DateTime>{};
      for (final done in entry.value.entries) {
        final ritual = AccueilRitual.values
            .where((value) => value.name == done.key)
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
      if (monday == null || entry.value is! Map) continue;
      final completedAt = <CivilDay, DateTime>{};
      final rawDone = entry.value['completedAt'];
      if (rawDone is Map) {
        for (final done in rawDone.entries) {
          final day = CivilDay.tryParse(done.key as String? ?? '');
          final at = DateTime.tryParse(done.value as String? ?? '');
          if (day != null && at != null) completedAt[day] = at.toUtc();
        }
      }
      weeks[monday] = SocialWeek(
        monday: monday,
        ideaIndex: entry.value['ideaIndex'] as int? ?? 0,
        completedAt: completedAt,
      );
    }
    return weeks;
  }

  Map<String, ThreadAnswer> _parseThreadAnswers(dynamic raw) {
    final answers = <String, ThreadAnswer>{};
    if (raw is! Map) return answers;
    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      final reply = ThreadReply.values
          .where((value) => value.name == entry.value['reply'])
          .firstOrNull;
      final at = DateTime.tryParse(entry.value['answeredAt'] as String? ?? '');
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
          .where((value) => value.name == entry.value)
          .firstOrNull;
      if (day != null && mood != null) moods[day] = mood;
    }
    return moods;
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
    _capThreadAnswers(facts.threadAnswers);
    return _commit(facts);
  }

  /// Un pas social au plus par date ; un second clic le même jour garde le
  /// premier horodatage.
  Future<bool> completeSocialStep({required CivilDay day}) {
    final monday = _mondayOf(day);
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
    final monday = _mondayOf(day);
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

  /// Note l'humeur choisie ce jour-là, du même pas que la sélection de
  /// l'Accueil. La dernière humeur du jour gagne.
  Future<bool> recordMood({required CivilDay day, required MoodType mood}) {
    final facts = _Facts.of(_snapshot);
    if (facts.moodDays[day] == mood) return Future.value(true);
    facts.moodDays[day] = mood;
    return _commit(facts);
  }

  CivilDay _mondayOf(CivilDay day) => day.addDays(-(day.weekday - 1));

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
    };
  }

  /// Élague les faits trop vieux : 370 jours de rétention, pas plus.
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
    _prune(facts);
    final confirmed = _snapshot;
    _snapshot = facts.snapshot(isWriting: true);
    _notify();
    final write = _writes.then((_) async {
      final encrypted = await cipher.seal(
        scope,
        jsonEncode(_document(facts)),
        purpose: _purpose,
      );
      final prefs = await _prefs;
      final saved = await prefs.setString(_key, encrypted);
      if (!saved) throw StateError('Accueil activities write refused');
    });
    _writes = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    try {
      await write;
    } catch (_) {
      // Le document confirmé survit à l'échec ; l'erreur est visible et la
      // commande peut être rejouée.
      if (!_disposed && revision == _revision) {
        _snapshot = AccueilActivitySnapshot(
          rituals: confirmed.rituals,
          socialWeeks: confirmed.socialWeeks,
          threadAnswers: confirmed.threadAnswers,
          moodDays: confirmed.moodDays,
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
