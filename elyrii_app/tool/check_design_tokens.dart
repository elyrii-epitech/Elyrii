// Screens pick AppTextStyles roles, AppDimensions steps and the theme's text
// colors. Only lib/core/theme defines raw values.
import 'dart:io';

final _rules = <String, RegExp>{
  'text style value (use an AppTextStyles role)': RegExp(
    r'\b(fontSize|fontFamily|fontWeight)\s*:',
  ),
  'radius (use AppDimensions.radius*)': RegExp(
    r'\b(Border)?Radius\.circular\(\s*\d',
  ),
  'gap (use AppDimensions.spacing*)': RegExp(
    r'SizedBox\(\s*(height|width):\s*\d*[1-9][\d.]*\s*,?\s*\)',
  ),
  'spacing (use AppDimensions.spacing*)': RegExp(
    r'\b(spacing|runSpacing|mainAxisSpacing|crossAxisSpacing)\s*:\s*\d*[1-9]',
  ),
  'text color (use context.textPrimary/Secondary/Tertiary)': RegExp(
    r'\?\s*AppColors\.text(Primary|Secondary|Tertiary)Dark\s*:\s*AppColors\.text(Primary|Secondary|Tertiary)Light',
  ),
};

final _insets = RegExp(r'EdgeInsets(Directional)?\.\w+\(');
final _number = RegExp(r'(?<![\w.])\d+(\.\d+)?(?![\w.])');

void main() {
  final violations = <String>[];
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where(
        (f) => !f.path.replaceAll(r'\', '/').startsWith('lib/core/theme/'),
      );
  for (final file in files) {
    final source = file.readAsStringSync();
    int lineOf(int offset) =>
        '\n'.allMatches(source.substring(0, offset)).length + 1;
    for (final MapEntry(key: rule, value: pattern) in _rules.entries) {
      for (final match in pattern.allMatches(source)) {
        violations.add('${file.path}:${lineOf(match.start)}: $rule');
      }
    }
    for (final match in _insets.allMatches(source)) {
      var depth = 1;
      var end = match.end;
      while (depth > 0 && end < source.length) {
        final char = source[end++];
        if (char == '(') depth++;
        if (char == ')') depth--;
      }
      final args = source.substring(match.end, end - 1);
      if (_number.allMatches(args).any((n) => double.parse(n[0]!) != 0)) {
        violations.add(
          '${file.path}:${lineOf(match.start)}: inset (use AppDimensions.spacing*)',
        );
      }
    }
  }
  if (violations.isEmpty) return;
  violations.forEach(stderr.writeln);
  stderr.writeln(
    '${violations.length} raw design values outside lib/core/theme.',
  );
  exitCode = 1;
}
