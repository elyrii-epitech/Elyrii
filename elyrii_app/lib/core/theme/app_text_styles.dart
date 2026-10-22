import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The only type scale of the app. Screens pick a role, never a size, so a
/// title on one page matches the same title on every other page.
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle _baseStyle = TextStyle(fontFamily: 'Poppins');

  static TextStyle _role(
    double size,
    FontWeight weight,
    double height,
    double letterSpacing, {
    Color? color,
    FontWeight? fontWeight,
  }) => _baseStyle.copyWith(
    fontSize: size,
    fontWeight: fontWeight ?? weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  // ==================== DISPLAY & HEADLINE ====================

  /// Launch wordmark and very large hero numbers.
  static TextStyle displaySmall({Color? color, FontWeight? fontWeight}) =>
      _role(
        36,
        FontWeight.w600,
        1.2,
        -0.5,
        color: color,
        fontWeight: fontWeight,
      );

  /// Root page title, rendered by `ElyriiPageFrame` only.
  static TextStyle pageTitle({Color? color, FontWeight? fontWeight}) => _role(
    28,
    FontWeight.w700,
    1.1,
    -0.6,
    color: color,
    fontWeight: fontWeight,
  );

  /// Auth and onboarding headings.
  static TextStyle headlineMedium({Color? color, FontWeight? fontWeight}) =>
      _role(
        28,
        FontWeight.w600,
        1.25,
        -0.3,
        color: color,
        fontWeight: fontWeight,
      );

  /// Stat numbers and hero values.
  static TextStyle headlineSmall({Color? color, FontWeight? fontWeight}) =>
      _role(
        24,
        FontWeight.w700,
        1.25,
        -0.3,
        color: color,
        fontWeight: fontWeight,
      );

  // ==================== TITLES ====================

  /// Sheet and dialog titles.
  static TextStyle titleLarge({Color? color, FontWeight? fontWeight}) => _role(
    20,
    FontWeight.w600,
    1.3,
    -0.2,
    color: color,
    fontWeight: fontWeight,
  );

  /// Section titles and navigation titles.
  static TextStyle titleMedium({Color? color, FontWeight? fontWeight}) => _role(
    17,
    FontWeight.w600,
    1.35,
    -0.1,
    color: color,
    fontWeight: fontWeight,
  );

  /// Card and row titles.
  static TextStyle titleSmall({Color? color, FontWeight? fontWeight}) =>
      _role(15, FontWeight.w600, 1.4, 0, color: color, fontWeight: fontWeight);

  // ==================== BODY ====================

  /// Reading text, inputs and chat messages.
  static TextStyle bodyLarge({Color? color, FontWeight? fontWeight}) => _role(
    16,
    FontWeight.w400,
    1.5,
    0.1,
    color: color,
    fontWeight: fontWeight,
  );

  static TextStyle bodyMedium({Color? color, FontWeight? fontWeight}) => _role(
    14,
    FontWeight.w400,
    1.45,
    0.1,
    color: color,
    fontWeight: fontWeight,
  );

  /// Secondary and meta text.
  static TextStyle bodySmall({Color? color, FontWeight? fontWeight}) => _role(
    12,
    FontWeight.w400,
    1.35,
    0.2,
    color: color,
    fontWeight: fontWeight,
  );

  // ==================== LABELS ====================

  /// Button labels.
  static TextStyle labelLarge({Color? color, FontWeight? fontWeight}) => _role(
    15,
    FontWeight.w600,
    1.33,
    0.2,
    color: color,
    fontWeight: fontWeight,
  );

  /// Chips, overlines and small emphasized labels.
  static TextStyle labelMedium({Color? color, FontWeight? fontWeight}) => _role(
    13,
    FontWeight.w600,
    1.35,
    0.2,
    color: color,
    fontWeight: fontWeight,
  );

  /// Tags and badges. 11 pt is the smallest text the app renders.
  static TextStyle labelSmall({Color? color, FontWeight? fontWeight}) => _role(
    11,
    FontWeight.w500,
    1.45,
    0.4,
    color: color,
    fontWeight: fontWeight,
  );

  /// Monospace debug output.
  static TextStyle code({Color? color}) => TextStyle(
    fontFamily: 'monospace',
    fontSize: 12,
    height: 1.4,
    color: color,
  );

  // ==================== FORM ====================

  static TextStyle inputHint() => bodyLarge(color: AppColors.textTertiaryLight);

  static TextStyle error() => bodySmall(color: AppColors.error);

  /// Material's text roles, so widgets that read `Theme.textTheme` follow
  /// the same scale.
  static TextTheme textTheme(Color primary, Color secondary) => TextTheme(
    displaySmall: displaySmall(color: primary),
    headlineMedium: headlineMedium(color: primary),
    headlineSmall: headlineSmall(color: primary),
    titleLarge: titleLarge(color: primary),
    titleMedium: titleMedium(color: primary),
    titleSmall: titleSmall(color: primary),
    bodyLarge: bodyLarge(color: primary),
    bodyMedium: bodyMedium(color: primary),
    bodySmall: bodySmall(color: secondary),
    labelLarge: labelLarge(color: primary),
    labelMedium: labelMedium(color: primary),
    labelSmall: labelSmall(color: secondary),
  );
}
