import '../../dashboard/domain/civil_day.dart';
import '../data/models/gamification_models.dart';

/// Avancement d'un jour du Jardin : parmi les défis qui existaient et
/// n'étaient pas encore terminés ce jour-là, combien ont été terminés ce jour.
class GardenDayProgress {
  const GardenDayProgress({
    required this.day,
    required this.completed,
    required this.total,
  });

  final CivilDay day;
  final int completed;
  final int total;

  /// `null` quand aucun défi n'est concerné (jour futur ou sans défi) :
  /// distinct d'un taux de 0 sur des défis réellement proposés.
  double? get completionRate => total == 0 ? null : completed / total;
}

/// Un [GardenDayProgress] par jour de [month], dans l'ordre.
///
/// Un défi est concerné un jour donné s'il a été créé ce jour ou avant, et
/// s'il n'a pas été terminé un jour antérieur. Un défi actif l'est donc de sa
/// création à aujourd'hui ; un défi terminé l'est de sa création au jour de sa
/// complétion inclus. Seule la date réelle `completedAt` compte au
/// numérateur ; `updatedAt` n'est jamais une date de complétion.
///
/// Les jours après [today] valent 0 sur 0. Sont écartés : un défi terminé sans
/// `completedAt` (historique inconnu), un défi terminé avant d'avoir été créé
/// (dates incohérentes), un défi de [activeChallenges] qui n'est pas `ACTIVE`.
/// Un même identifiant n'est compté qu'une fois, la version terminée
/// l'emportant sur la version active.
List<GardenDayProgress> buildGardenProgress({
  required CivilDay today,
  required CivilMonth month,
  required List<UserChallenge> activeChallenges,
  required List<UserChallenge> completedChallenges,
}) {
  final days = month.days;
  final first = days.first;
  final dayCount = days.length;
  // Différences successives : +1 au premier jour concerné, -1 après le
  // dernier. Un seul balayage donne ensuite le dénominateur de chaque jour.
  final totalDelta = List<int>.filled(dayCount + 1, 0);
  final completedPerDay = List<int>.filled(dayCount, 0);
  final seen = <String>{};

  for (final challenge in completedChallenges) {
    if (!seen.add(challenge.id)) continue;
    final completedAt = challenge.completedAt;
    if (completedAt == null) continue;
    final created = CivilDay.fromLocal(challenge.createdAt);
    final completed = CivilDay.fromLocal(completedAt);
    if (completed.isBefore(created)) continue;
    final start = _within(first.daysUntil(created), dayCount);
    final end = first.daysUntil(completed);
    if (end < 0) continue;
    if (end < dayCount) completedPerDay[end]++;
    totalDelta[start]++;
    totalDelta[_within(end + 1, dayCount)]--;
  }

  for (final challenge in activeChallenges) {
    if (!challenge.isActive || !seen.add(challenge.id)) continue;
    final start = _within(
      first.daysUntil(CivilDay.fromLocal(challenge.createdAt)),
      dayCount,
    );
    totalDelta[start]++;
    totalDelta[dayCount]--;
  }

  var running = 0;
  return List.generate(dayCount, (index) {
    running += totalDelta[index];
    final day = days[index];
    final counted = day.isAfter(today);
    return GardenDayProgress(
      day: day,
      completed: counted ? 0 : completedPerDay[index],
      total: counted ? 0 : running,
    );
  }, growable: false);
}

int _within(int index, int max) => index < 0
    ? 0
    : index > max
    ? max
    : index;
