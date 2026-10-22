/// Jour civil : une date de calendrier sans heure ni fuseau, clé de
/// l'historique Accueil et du store d'activités.
///
/// Les comparaisons et l'arithmétique passent par des dates UTC construites
/// depuis les composantes, jamais par un `Duration(days: 1)` ajouté à une
/// heure locale : un changement d'heure ne doit pas décaler un jour.
class CivilDay implements Comparable<CivilDay> {
  static const List<int> _monthLengths = [
    31,
    28,
    31,
    30,
    31,
    30,
    31,
    31,
    30,
    31,
    30,
    31,
  ];

  static int _daysInMonth(int year, int month) {
    if (month == DateTime.february && _isLeapYear(year)) return 29;
    return _monthLengths[month - 1];
  }

  static bool _isLeapYear(int year) =>
      (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

  /// Comme [parse] mais renvoie null au lieu de lever, pour l'analyse
  /// tolérante des documents locaux.
  static CivilDay? tryParse(String isoDate) {
    try {
      return CivilDay.parse(isoDate);
    } on FormatException {
      return null;
    }
  }

  /// Analyse une date `YYYY-MM-DD` telle que renvoyée par le serveur, sans
  /// la convertir en instant : les composantes sont conservées telles
  /// quelles. Une valeur mal formée est une erreur de contrat.
  factory CivilDay.parse(String isoDate) {
    final match = _isoDay.firstMatch(isoDate);
    if (match == null) {
      throw FormatException('Invalid civil day: $isoDate');
    }
    return CivilDay(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  /// Extraie le jour civil d'un instant, dans le fuseau local de l'appareil.
  factory CivilDay.fromLocal(DateTime instant) {
    final local = instant.toLocal();
    return CivilDay(local.year, local.month, local.day);
  }

  static final RegExp _isoDay = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  CivilDay(this.year, this.month, this.day) {
    final validMonth = month >= 1 && month <= 12;
    if (!validMonth || day < 1 || day > _daysInMonth(year, month)) {
      throw FormatException('Invalid civil day: $year-$month-$day');
    }
  }

  final int year;
  final int month;
  final int day;

  DateTime get _utcDate => DateTime.utc(year, month, day);

  /// La même date au format `YYYY-MM-DD` du serveur.
  String get isoDate =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  /// Lundi vaut 1, dimanche vaut 7, comme `DateTime.weekday`.
  int get weekday => _utcDate.weekday;

  CivilMonth get civilMonth => CivilMonth(year, month);

  CivilDay addDays(int count) {
    final shifted = _utcDate.add(Duration(days: count));
    return CivilDay(shifted.year, shifted.month, shifted.day);
  }

  /// Nombre de jours jusqu'à [other] : positif si [other] est plus tard.
  int daysUntil(CivilDay other) => other._utcDate.difference(_utcDate).inDays;

  @override
  int compareTo(CivilDay other) => _utcDate.compareTo(other._utcDate);

  @override
  bool operator ==(Object other) =>
      other is CivilDay &&
      year == other.year &&
      month == other.month &&
      day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  bool isBefore(CivilDay other) => compareTo(other) < 0;

  bool isAfter(CivilDay other) => compareTo(other) > 0;

  @override
  String toString() => isoDate;
}

/// Un mois civil complet, du premier au dernier jour.
class CivilMonth {
  CivilMonth(this.year, this.month) {
    if (month < 1 || month > 12) {
      throw FormatException('Invalid civil month: $year-$month');
    }
  }

  factory CivilMonth.containing(CivilDay day) =>
      CivilMonth(day.year, day.month);

  final int year;
  final int month;

  CivilDay get firstDay => CivilDay(year, month, 1);

  CivilDay get lastDay =>
      CivilDay(year, month, CivilDay._daysInMonth(year, month));

  /// Le mois décalé de [months] mois, en avant ou en arrière.
  CivilMonth shifted(int months) {
    final zeroBased = year * 12 + (month - 1) + months;
    return CivilMonth(zeroBased ~/ 12, zeroBased % 12 + 1);
  }

  List<CivilDay> get days =>
      List.generate(lastDay.day, (index) => CivilDay(year, month, index + 1));

  @override
  bool operator ==(Object other) =>
      other is CivilMonth && year == other.year && month == other.month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => '$year-${month.toString().padLeft(2, '0')}';
}

/// Plage de jours réellement couverte par un historique chargé. Un jour hors
/// plage est inconnu, jamais absent.
class CalendarCoverage {
  const CalendarCoverage({required this.firstDay, required this.throughDay});

  final CivilDay firstDay;
  final CivilDay throughDay;

  bool contains(CivilDay day) =>
      !day.isBefore(firstDay) && !day.isAfter(throughDay);

  /// Le mois est exploitable quand toute sa partie écoulée est couverte :
  /// entièrement pour un mois passé, jusqu'à aujourd'hui pour le mois
  /// courant. Un mois futur n'est jamais couvert.
  bool containsMonth(CivilMonth month, CivilDay today) {
    if (month.firstDay.isAfter(today)) return false;
    final lastElapsedDay = month.lastDay.isAfter(today) ? today : month.lastDay;
    return !firstDay.isAfter(month.firstDay) && contains(lastElapsedDay);
  }

  @override
  String toString() => '$firstDay..$throughDay';
}
