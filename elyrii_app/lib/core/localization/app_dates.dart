import 'package:intl/intl.dart';

/// A deterministic fallback also makes reusable sheets safe before bootstrap.
abstract final class AppDates {
  static String format(DateTime date, String pattern, {String locale = 'fr'}) {
    if (DateFormat.localeExists(locale)) {
      return DateFormat(pattern, locale).format(date);
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
