/// Civil day: a calendar date without time or timezone, used as the key for
/// Home history and the activity store. Comparisons and arithmetic use UTC
/// dates constructed from components, never `Duration(days: 1)` added to a
/// local time, so daylight-saving changes cannot shift a day.
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

  /// Like [parse], but returns null instead of throwing, for tolerant parsing
  /// of local documents.
  static CivilDay? tryParse(String isoDate) {
    try {
      return CivilDay.parse(isoDate);
    } on FormatException {
      return null;
    }
  }

  /// Parses a server `YYYY-MM-DD` date without converting it to an instant;
  /// components remain unchanged. Malformed values are contract errors.
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

  /// Extracts an instant's civil day in the device's local timezone.
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

  /// The same date in the server's `YYYY-MM-DD` format.
  String get isoDate =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  /// Monday is 1 and Sunday is 7, matching `DateTime.weekday`.
  int get weekday => _utcDate.weekday;

  CivilMonth get civilMonth => CivilMonth(year, month);

  CivilDay addDays(int count) {
    final shifted = _utcDate.add(Duration(days: count));
    return CivilDay(shifted.year, shifted.month, shifted.day);
  }

  /// Days until [other], positive when [other] is later.
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

/// A complete civil month, from its first to last day.
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

  /// The month shifted forward or backward by [months].
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

/// Day range actually covered by loaded history. A day outside the range is
/// unknown, never absent.
class CalendarCoverage {
  const CalendarCoverage({required this.firstDay, required this.throughDay});

  final CivilDay firstDay;
  final CivilDay throughDay;

  bool contains(CivilDay day) =>
      !day.isBefore(firstDay) && !day.isAfter(throughDay);

  /// A month is usable when its entire elapsed portion is covered: all of a
  /// past month, or through today for the current month. Future months are
  /// never covered.
  bool containsMonth(CivilMonth month, CivilDay today) {
    if (month.firstDay.isAfter(today)) return false;
    final lastElapsedDay = month.lastDay.isAfter(today) ? today : month.lastDay;
    return !firstDay.isAfter(month.firstDay) && contains(lastElapsedDay);
  }

  @override
  String toString() => '$firstDay..$throughDay';
}
