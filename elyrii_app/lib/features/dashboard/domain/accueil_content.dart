import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../gamification/data/models/gamification_models.dart';
import '../../journal/data/models/journal_entry_model.dart';
import '../data/accueil_activities.dart';
import '../data/models/dashboard_models.dart';
import '../presentation/mood_presentation.dart';
import 'civil_day.dart';

// ==================== MOMENT DE LA JOURNÉE ====================

enum DayPart { morning, afternoon, evening }

/// Matin avant 12 h, après-midi de 12 h à 17 h 59, soir à partir de 18 h.
DayPart dayPartOf(DateTime local) {
  if (local.hour < 12) return DayPart.morning;
  if (local.hour < 18) return DayPart.afternoon;
  return DayPart.evening;
}

extension on DayPart {
  String get thisPart => switch (this) {
    DayPart.morning => 'ce matin',
    DayPart.afternoon => 'cet après-midi',
    DayPart.evening => 'ce soir',
  };

  String get aPart => switch (this) {
    DayPart.morning => 'un matin',
    DayPart.afternoon => 'un après-midi',
    DayPart.evening => 'un soir',
  };

  String get yourPart => switch (this) {
    DayPart.morning => 'ta matinée',
    DayPart.afternoon => 'ton après-midi',
    DayPart.evening => 'ta soirée',
  };
}

String _capitalize(String text) =>
    text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

/// « Comment te sens-tu ce soir ? », selon le moment de la journée.
String moodQuestion(DateTime now) =>
    'Comment te sens-tu ${dayPartOf(now).thisPart} ?';

// ==================== ACTIONS ET RÉPONSES ====================

/// Ce qu'une action de l'Accueil déclenche réellement ; la page l'exécute.
sealed class AccueilAction {
  const AccueilAction();
}

final class OpenChat extends AccueilAction {
  const OpenChat();
}

final class Breathe extends AccueilAction {
  final Duration duration;
  const Breathe(this.duration);
}

final class WriteJournal extends AccueilAction {
  final String initialPrompt;
  const WriteJournal(this.initialPrompt);
}

final class ContactSomeone extends AccueilAction {
  const ContactSomeone();
}

final class CallHelp extends AccueilAction {
  const CallHelp();
}

final class OpenReviews extends AccueilAction {
  const OpenReviews();
}

class AccueilAnswerAction {
  final String label;
  final AccueilAction action;
  final bool filled;
  final IconData icon;

  const AccueilAnswerAction({
    required this.label,
    required this.action,
    required this.filled,
    required this.icon,
  });
}

class AccueilAnswer {
  final String title;
  final String body;
  final List<AccueilAnswerAction> actions;
  final bool isSoftPink;
  final bool showsHelp;

  const AccueilAnswer({
    required this.title,
    required this.body,
    required this.actions,
    this.isSoftPink = false,
    this.showsHelp = false,
  });
}

/// Ligne d'aide affichée seulement pour l'humeur Éprouvé.
const helpLine = 'Besoin d\'aide maintenant · 3114, gratuit, jour et nuit';

/// Le texte de partage proposé par « Écrire à un proche ».
const contactShareText = 'Je pensais à toi.';

/// La table ANSWERS de la maquette, exhaustive sur `MoodType?`. Seules les
/// références au moment de la journée changent ; « Rappel coucher » est
/// retiré faute de service de rappel.
AccueilAnswer answerForMood(MoodType? mood, DateTime now) {
  final part = dayPartOf(now);
  switch (mood) {
    case null:
      return AccueilAnswer(
        title: 'Dis-moi comment tu vas.',
        body: 'Je m\'adapte à ${part.yourPart} : un geste, pas une liste.',
        actions: const [],
      );
    case MoodType.verySad:
      return AccueilAnswer(
        title: 'Ça a l\'air lourd ${part.thisPart}.',
        body: 'Tu n\'as rien à faire de plus. On peut en parler, ou juste respirer une minute ensemble.',
        actions: const [
          AccueilAnswerAction(
            label: 'Parler à Elyrii',
            action: OpenChat(),
            filled: true,
            icon: Symbols.chat_bubble_rounded,
          ),
          AccueilAnswerAction(
            label: 'Respirer 1 min',
            action: Breathe(Duration(minutes: 1)),
            filled: false,
            icon: Symbols.air_rounded,
          ),
        ],
        isSoftPink: true,
        showsHelp: true,
      );
    case MoodType.sad:
      return AccueilAnswer(
        title: 'Merci de me le dire.',
        body:
            'Une petite chose douce suffit ${part.thisPart}. Écrire trois lignes aide souvent à poser ce qui pèse.',
        actions: const [
          AccueilAnswerAction(
            label: 'Écrire 3 lignes',
            action: WriteJournal('Trois lignes sur ce qui pèse'),
            filled: true,
            icon: Symbols.edit_rounded,
          ),
          AccueilAnswerAction(
            label: 'En parler',
            action: OpenChat(),
            filled: false,
            icon: Symbols.chat_bubble_rounded,
          ),
        ],
        isSoftPink: true,
      );
    case MoodType.neutral:
      return AccueilAnswer(
        title: '${_capitalize(part.aPart)} paisible, ça se garde.',
        body: part == DayPart.evening
            ? 'Deux minutes de respiration avant de dormir prolongent ce calme.'
            : 'Deux minutes de respiration prolongent ce calme.',
        actions: const [
          AccueilAnswerAction(
            label: 'Respirer 2 min',
            action: Breathe(Duration(minutes: 2)),
            filled: true,
            icon: Symbols.air_rounded,
          ),
        ],
      );
    case MoodType.happy:
      return AccueilAnswer(
        title: 'Content de te savoir serein.',
        body:
            'Note ce qui a rendu ta journée douce, tu pourras le relire ${part.aPart} plus gris.',
        actions: const [
          AccueilAnswerAction(
            label: 'Écrire une gratitude',
            action: WriteJournal('Ce qui a rendu ma journée douce'),
            filled: true,
            icon: Symbols.edit_rounded,
          ),
          AccueilAnswerAction(
            label: 'Respirer',
            action: Breathe(Duration(minutes: 2)),
            filled: false,
            icon: Symbols.air_rounded,
          ),
        ],
      );
    case MoodType.veryHappy:
      return AccueilAnswer(
        title: 'Tu rayonnes ${part.thisPart} !',
        body: 'C\'est le bon moment pour partager un peu de cette énergie avec quelqu\'un.',
        actions: const [
          AccueilAnswerAction(
            label: 'Écrire à un proche',
            action: ContactSomeone(),
            filled: true,
            icon: Symbols.favorite_rounded,
          ),
          AccueilAnswerAction(
            label: 'Garder une trace',
            action: WriteJournal('Ce qui me fait rayonner'),
            filled: false,
            icon: Symbols.edit_rounded,
          ),
        ],
      );
  }
}

// ==================== MATRICE D'HUMEUR ====================

/// Les sections affichées sous l'humeur. Le soutien passe d'abord pour
/// Éprouvé et Vulnérable ; le lien social disparaît seulement pour Éprouvé.
/// Le fil et l'insight ne dépendent pas de l'humeur.
class AccueilMoodLayout {
  final bool showsRituals;
  final bool showsRest;
  final bool showsSocial;

  const AccueilMoodLayout({
    required this.showsRituals,
    required this.showsRest,
    required this.showsSocial,
  });
}

AccueilMoodLayout layoutForMood(MoodType? mood) => switch (mood) {
  MoodType.verySad => const AccueilMoodLayout(
    showsRituals: false,
    showsRest: true,
    showsSocial: false,
  ),
  MoodType.sad => const AccueilMoodLayout(
    showsRituals: false,
    showsRest: true,
    showsSocial: true,
  ),
  _ => const AccueilMoodLayout(
    showsRituals: true,
    showsRest: false,
    showsSocial: true,
  ),
};

const restTitle = 'Les rituels peuvent attendre';

/// Le repos ne promet aucun mécanisme de jour de repos : il décrit ce que
/// la série sait vraiment.
String restBody({required bool moodSaved}) => moodSaved
    ? 'Ton humeur est notée aujourd\'hui. Ta série compte ce jour.'
    : 'Les rituels peuvent attendre. Prends ce temps pour toi.';

// ==================== RITUELS ====================

class AccueilRitualInfo {
  final AccueilRitual ritual;
  final String title;
  final String pendingDetail;
  final IconData icon;
  final Color Function(bool isDark) color;

  const AccueilRitualInfo({
    required this.ritual,
    required this.title,
    required this.pendingDetail,
    required this.icon,
    required this.color,
  });
}

const ritualsTitle = 'Rituels du jour';

const accueilRituals = [
  AccueilRitualInfo(
    ritual: AccueilRitual.breathe,
    title: 'Respirer 2 minutes',
    pendingDetail: '2 min · Respiration',
    icon: Symbols.air_rounded,
    color: AppColors.teal,
  ),
  AccueilRitualInfo(
    ritual: AccueilRitual.gratitude,
    title: 'Écrire une gratitude',
    pendingDetail: '3 min · Journal',
    icon: Symbols.edit_rounded,
    color: AppColors.yellow,
  ),
  AccueilRitualInfo(
    ritual: AccueilRitual.walk,
    title: 'Marcher 10 minutes',
    pendingDetail: '10 min · Dehors',
    icon: Symbols.directions_walk_rounded,
    color: AppColors.green,
  ),
];

/// « Fait à 21:46 » une fois réalisé, le détail du rituel sinon.
String ritualDetail(AccueilRitualInfo info, DateTime? completedAt) {
  if (completedAt == null) return info.pendingDetail;
  final local = completedAt.toLocal();
  final hours = local.hour.toString().padLeft(2, '0');
  final minutes = local.minute.toString().padLeft(2, '0');
  return 'Fait à $hours:$minutes';
}

String ritualCounter(int done) => '$done sur ${accueilRituals.length}';

// ==================== LIEN SOCIAL ====================

const socialTitle = 'Un pas vers les autres';
const socialWeeklyGoal = 3;

const socialIdeas = [
  'Écris à quelqu\'un qui compte pour toi. Même juste « je pensais à toi ».',
  'Remercie quelqu\'un pour un petit geste de cette semaine.',
  'Prends des nouvelles d\'une personne que tu n\'as pas vue depuis un moment.',
  'Propose un appel de cinq minutes à un proche.',
  'Partage un souvenir heureux avec quelqu\'un qui y était.',
];

String socialIdeaAt(int index) => socialIdeas[index % socialIdeas.length];

/// Le but est trois pas ; quatre restent une mesure vraie.
String socialCounter(int steps) =>
    '$steps pas sur $socialWeeklyGoal cette semaine';

// ==================== FIL ====================

class AccueilThread {
  final String entryId;
  final String preamble;
  final String quote;
  final String question;
  final ThreadAnswer? answer;

  const AccueilThread({
    required this.entryId,
    required this.preamble,
    required this.quote,
    required this.question,
    required this.answer,
  });
}

const threadQuestion = 'Comment tu te sens depuis ?';

String threadReplyLabel(ThreadReply reply) => switch (reply) {
  ThreadReply.ratherGood => 'Plutôt bien',
  ThreadReply.notGreat => 'Bof',
};

/// La ligne d'Elyrii après une réponse ; elle ne prétend pas connaître
/// l'issue d'un événement privé.
String threadReplyLine(ThreadReply reply) => switch (reply) {
  ThreadReply.ratherGood => 'Je suis content que tu te sentes mieux.',
  ThreadReply.notGreat =>
    'Merci de me le dire. On peut en parler à ton rythme.',
};

const _weekdayNames = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];

/// Le fil reprend la dernière entrée de Journal des trois derniers jours,
/// quel que soit l'ordre d'affichage du Journal.
AccueilThread? projectThread({
  required List<JournalEntryModel> entries,
  required DateTime now,
  required AccueilActivitySnapshot activities,
}) {
  JournalEntryModel? latest;
  for (final entry in entries) {
    final age = now.difference(entry.createdAt);
    if (age.isNegative || age > const Duration(days: 3)) continue;
    if (latest == null || entry.createdAt.isAfter(latest.createdAt)) {
      latest = entry;
    }
  }
  if (latest == null) return null;
  final quote = _quoteOf(latest);
  if (quote == null) return null;
  return AccueilThread(
    entryId: latest.id,
    preamble: '${_relativePhrase(latest.createdAt, now)}, tu m\'as confié',
    quote: quote,
    question: threadQuestion,
    answer: activities.threadAnswers[latest.id],
  );
}

String? _quoteOf(JournalEntryModel entry) {
  final title = entry.title.trim();
  if (title.isNotEmpty) return title;
  final content = entry.content?.trim() ?? '';
  if (content.isEmpty) return null;
  final end = RegExp(r'[.!?…]').firstMatch(content);
  return end == null ? content : content.substring(0, end.end);
}

String _relativePhrase(DateTime createdAt, DateTime now) {
  final local = createdAt.toLocal();
  final day = CivilDay.fromLocal(local);
  final today = CivilDay.fromLocal(now);
  final part = dayPartOf(local);
  final gap = day.daysUntil(today);
  if (gap == 0) return _capitalize(part.thisPart);
  if (gap == 1) {
    return switch (part) {
      DayPart.morning => 'Hier matin',
      DayPart.afternoon => 'Hier après-midi',
      DayPart.evening => 'Hier soir',
    };
  }
  return _capitalize(_weekdayNames[day.weekday - 1]);
}

// ==================== CALENDRIER ====================

enum CalendarCellState {
  presentWithMood,
  presentWithoutMood,
  absent,
  uncovered,
  future,
}

class CalendarCell {
  final CivilDay day;
  final CalendarCellState state;
  final MoodType? mood;
  final bool isToday;
  final bool inStreak;
  final int journalEntries;

  /// Rituels connus de cet appareil ; null quand le store ignore ce jour.
  final int? ritualsDone;

  const CalendarCell({
    required this.day,
    required this.state,
    required this.mood,
    required this.isToday,
    required this.inStreak,
    required this.journalEntries,
    required this.ritualsDone,
  });

  bool get isPresent =>
      state == CalendarCellState.presentWithMood ||
      state == CalendarCellState.presentWithoutMood;
}

class CalendarMonth {
  final CivilMonth month;

  /// Cases vides avant le 1er, la semaine commençant le lundi.
  final int leadingBlanks;
  final List<CalendarCell> cells;
  final int presentDays;
  final int elapsedDays;

  const CalendarMonth({
    required this.month,
    required this.leadingBlanks,
    required this.cells,
    required this.presentDays,
    required this.elapsedDays,
  });
}

CalendarCellState _stateOf(
  CivilDay day, {
  required CivilDay today,
  required Map<CivilDay, ActivityTimelinePoint> history,
  required CalendarCoverage? coverage,
  required AccueilActivitySnapshot activities,
}) {
  if (day.isAfter(today)) return CalendarCellState.future;
  if (activities.moodDays.containsKey(day)) {
    return CalendarCellState.presentWithMood;
  }
  final point = history[day];
  if (point != null && (point.moodLogs > 0 || point.journalEntries > 0)) {
    return CalendarCellState.presentWithoutMood;
  }
  if (coverage != null && coverage.contains(day)) {
    return CalendarCellState.absent;
  }
  return CalendarCellState.uncovered;
}

/// Jours de série vérifiables : des jours présents consécutifs finissant
/// aujourd'hui, ou hier si aujourd'hui n'a pas encore d'activité, bornés par
/// la série du serveur. Un trou ou un jour inconnu arrête la bande.
Set<CivilDay> _streakDays({
  required CivilDay today,
  required int currentStreak,
  required bool Function(CivilDay day) isPresent,
}) {
  final days = <CivilDay>{};
  var day = isPresent(today) ? today : today.addDays(-1);
  while (days.length < currentStreak && isPresent(day)) {
    days.add(day);
    day = day.addDays(-1);
  }
  return days;
}

CalendarMonth buildCalendarMonth({
  required CivilMonth month,
  required CivilDay today,
  required Map<CivilDay, ActivityTimelinePoint> history,
  required CalendarCoverage? coverage,
  required AccueilActivitySnapshot activities,
  required int currentStreak,
}) {
  CalendarCellState stateOf(CivilDay day) => _stateOf(
    day,
    today: today,
    history: history,
    coverage: coverage,
    activities: activities,
  );
  bool isPresent(CivilDay day) {
    final state = stateOf(day);
    return state == CalendarCellState.presentWithMood ||
        state == CalendarCellState.presentWithoutMood;
  }

  final streak = _streakDays(
    today: today,
    currentStreak: currentStreak,
    isPresent: isPresent,
  );
  final cells = [
    for (final day in month.days)
      CalendarCell(
        day: day,
        state: stateOf(day),
        mood: activities.moodDays[day],
        isToday: day == today,
        inStreak: streak.contains(day),
        journalEntries: history[day]?.journalEntries ?? 0,
        ritualsDone: activities.rituals[day]?.completedAt.length,
      ),
  ];
  return CalendarMonth(
    month: month,
    leadingBlanks: month.firstDay.weekday - 1,
    cells: cells,
    presentDays: cells.where((cell) => cell.isPresent).length,
    elapsedDays: cells.where((cell) => !cell.day.isAfter(today)).length,
  );
}

// ==================== SÉRIE ====================

enum StreakDayState { done, missed, upcoming }

class StreakDay {
  final CivilDay day;
  final StreakDayState state;
  final bool isToday;

  const StreakDay({
    required this.day,
    required this.state,
    required this.isToday,
  });
}

/// La semaine du lundi au dimanche. Les jours de la série du serveur sont
/// faits ; [todayCounted] indique si aujourd'hui compte déjà dans la série.
List<StreakDay> buildStreakWeek({
  required CivilDay today,
  required int currentStreak,
  bool todayCounted = true,
}) {
  final monday = AccueilActivities.mondayOf(today);
  final last = todayCounted ? today : today.addDays(-1);
  final first = last.addDays(-(currentStreak - 1));
  return [
    for (var offset = 0; offset < 7; offset++)
      () {
        final day = monday.addDays(offset);
        final inStreak =
            currentStreak > 0 && !day.isBefore(first) && !day.isAfter(last);
        final state = inStreak
            ? StreakDayState.done
            : day.isBefore(today)
            ? StreakDayState.missed
            : StreakDayState.upcoming;
        return StreakDay(day: day, state: state, isToday: day == today);
      }(),
  ];
}

// ==================== FLEURS ====================

class WeekFlower {
  final String challengeId;
  final String title;
  final CivilDay day;
  final MoodType? mood;

  const WeekFlower({
    required this.challengeId,
    required this.title,
    required this.day,
    required this.mood,
  });
}

class WeekFlowers {
  final CivilDay monday;

  /// Fleurs groupées par jour de semaine, lundi vaut 1.
  final Map<int, List<WeekFlower>> byWeekday;
  final List<WeekFlower> all;

  const WeekFlowers({
    required this.monday,
    required this.byWeekday,
    required this.all,
  });
}

/// Une fleur par défi terminé cette semaine, dédupliquée par identifiant.
/// Sa couleur reprend l'humeur notée ce jour-là sur cet appareil. Un défi
/// sans date compte pour le Jardin, pas pour la semaine.
WeekFlowers buildWeekFlowers({
  required CivilDay today,
  required List<UserChallenge> completedChallenges,
  required AccueilActivitySnapshot activities,
}) {
  final monday = AccueilActivities.mondayOf(today);
  final sunday = monday.addDays(6);
  final seen = <String>{};
  final all = <WeekFlower>[];
  for (final challenge in completedChallenges) {
    final completedAt = challenge.completedAt;
    if (completedAt == null || !seen.add(challenge.id)) continue;
    final day = CivilDay.fromLocal(completedAt);
    if (day.isBefore(monday) || day.isAfter(sunday)) continue;
    all.add(
      WeekFlower(
        challengeId: challenge.id,
        title: challenge.displayTitle,
        day: day,
        mood: activities.moodDays[day],
      ),
    );
  }
  all.sort((a, b) => a.day.compareTo(b.day));
  return WeekFlowers(
    monday: monday,
    byWeekday: {
      for (var weekday = 1; weekday <= 7; weekday++)
        weekday: [
          for (final flower in all)
            if (flower.day.weekday == weekday) flower,
        ],
    },
    all: List.unmodifiable(all),
  );
}

// ==================== INSIGHT ====================

class AccueilInsight {
  final String title;
  final String sentence;
  final int journalMoodDays;
  final int otherMoodDays;

  const AccueilInsight({
    required this.title,
    required this.sentence,
    required this.journalMoodDays,
    required this.otherMoodDays,
  });
}

const _insightMinimumDays = 5;
const _insightMinimumGap = 0.5;

/// Une association, pas une cause : la moyenne ordinale des humeurs des
/// jours avec écrit contre celle des jours sans écrit, sur la plage couverte.
/// Absente avec moins de cinq jours par groupe ou un écart sous un demi
/// niveau.
AccueilInsight? deriveInsight({
  required Map<CivilDay, ActivityTimelinePoint> history,
  required CalendarCoverage? coverage,
  required AccueilActivitySnapshot activities,
}) {
  if (coverage == null) return null;
  final withJournal = <int>[];
  final without = <int>[];
  for (final entry in activities.moodDays.entries) {
    if (!coverage.contains(entry.key)) continue;
    final wrote = (history[entry.key]?.journalEntries ?? 0) > 0;
    (wrote ? withJournal : without).add(entry.value.index);
  }
  if (withJournal.length < _insightMinimumDays ||
      without.length < _insightMinimumDays) {
    return null;
  }
  double mean(List<int> values) =>
      values.reduce((a, b) => a + b) / values.length;
  if (mean(withJournal) - mean(without) < _insightMinimumGap) return null;
  return AccueilInsight(
    title: 'Ce qui t\'aide',
    sentence:
        'Sur cette période, ton humeur est plus haute les jours où tu écris.',
    journalMoodDays: withJournal.length,
    otherMoodDays: without.length,
  );
}
