import 'package:intl/intl.dart';

/// A deterministic fallback also makes reusable sheets safe before bootstrap.
abstract final class AppDates {
  static String format(DateTime date, String pattern, {String locale = 'fr'}) {
    try {
      return DateFormat(pattern, locale).format(date);
    } on Exception {
      // Locale data loads at bootstrap; sheets may build before it.
    } on ArgumentError {
      // Unknown locale.
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
