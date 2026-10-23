import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_design_tokens.dart';

void main() {
  test('flags raw design values', () {
    const sources = {
      'font size': 'Text(style: TextStyle(fontSize: 13))',
      'font weight': 'style.copyWith(fontWeight: FontWeight.w700)',
      'border radius': 'BorderRadius.circular(12)',
      'bare radius': 'BorderRadius.vertical(top: Radius.circular(8))',
      'gap': 'const SizedBox(height: 10)',
      'wrap spacing': 'Wrap(spacing: 6, children: [])',
      'inset': 'EdgeInsets.symmetric(horizontal: 14)',
      'inset with nested call': 'EdgeInsets.only(top: f(x) + 12)',
      'theme-blind text color': 'color: AppColors.textTertiaryLight',
    };
    for (final MapEntry(:key, :value) in sources.entries) {
      expect(designTokenViolations(value), hasLength(1), reason: key);
    }
  });

  test('accepts tokens, zero and sized boxes', () {
    const sources = [
      'BorderRadius.circular(AppDimensions.radius12)',
      'const SizedBox(height: AppDimensions.spacing8)',
      'EdgeInsets.fromLTRB(AppDimensions.spacing20, 0, 0, 0)',
      'SizedBox(width: 48, height: 48, child: icon)',
      'AppTextStyles.bodySmall(color: context.textSecondary)',
    ];
    for (final source in sources) {
      expect(designTokenViolations(source), isEmpty, reason: source);
    }
  });
}
