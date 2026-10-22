import 'package:flutter/material.dart';

/// The only type scale of the app. Each role fixes size, weight and spacing,
/// so screens pick a role and never tune a style.
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle _baseStyle = TextStyle(fontFamily: 'Poppins');

  static TextStyle _role(
    double size,
    FontWeight weight,
    double height,
    double letterSpacing,
    Color? color,
  ) => _baseStyle.copyWith(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  // ==================== DISPLAY & HEADLINE ====================

  /// The "elyrii" logotype on the launch screen: light and widely spaced.
  static TextStyle wordmark({Color? color}) =>
      _role(38, FontWeight.w500, 1.2, 3, color);

  /// Root page title, rendered by `ElyriiPageFrame` only.
  static TextStyle pageTitle({Color? color}) =>
      _role(28, FontWeight.w700, 1.1, -0.6, color);

  /// Auth and onboarding headings.
  static TextStyle headlineMedium({Color? color}) =>
      _role(28, FontWeight.w700, 1.25, -0.5, color);

  /// Stat numbers, hero values and large emoji.
  static TextStyle headlineSmall({Color? color}) =>
      _role(24, FontWeight.w700, 1.25, -0.3, color);

  // ==================== TITLES ====================

  /// Sheet and dialog titles.
  static TextStyle titleLarge({Color? color}) =>
      _role(20, FontWeight.w600, 1.3, -0.2, color);

  /// Section titles and card hero titles.
  static TextStyle titleMedium({Color? color}) =>
      _role(17, FontWeight.w700, 1.35, -0.2, color);

  /// Centered navigation titles, rendered by the page headers only.
  static TextStyle navTitle({Color? color}) =>
      _role(17, FontWeight.w600, 1.35, -0.1, color);

  /// Card and row titles.
  static TextStyle titleSmall({Color? color}) =>
      _role(15, FontWeight.w600, 1.4, 0, color);

  // ==================== BODY ====================

  /// Reading text, inputs and chat messages.
  static TextStyle bodyLarge({Color? color}) =>
      _role(16, FontWeight.w400, 1.5, 0.1, color);

  static TextStyle bodyMedium({Color? color}) =>
      _role(14, FontWeight.w400, 1.45, 0.1, color);

  /// Secondary and meta text. Medium weight: 12 pt Regular strokes are too
  /// thin to keep secondary greys readable on glass.
  static TextStyle bodySmall({Color? color}) =>
      _role(12, FontWeight.w500, 1.35, 0.2, color);

  // ==================== LABELS ====================

  /// Button labels, and the default action of a dialog.
  static TextStyle labelLarge({Color? color}) =>
      _role(15, FontWeight.w600, 1.33, 0.2, color);

  /// The other actions of a dialog, lighter than the default one.
  static TextStyle dialogAction({Color? color}) =>
      _role(15, FontWeight.w400, 1.33, 0.2, color);

  /// Chips, short labels and small values.
  static TextStyle labelMedium({Color? color}) =>
      _role(13, FontWeight.w600, 1.35, 0.2, color);

  /// Section labels above a group, and the home date.
  static TextStyle overline({Color? color}) =>
      _role(13, FontWeight.w700, 1.2, 0.6, color);

  /// Captions and dock labels. 11 pt is the smallest text the app renders.
  static TextStyle labelSmall({Color? color}) =>
      _role(11, FontWeight.w500, 1.45, 0.4, color);

  /// Tags and badges.
  static TextStyle badge({Color? color}) =>
      _role(11, FontWeight.w700, 1.3, 0.4, color);

  /// Monospace debug output.
  static TextStyle code({Color? color}) => TextStyle(
    fontFamily: 'monospace',
    fontSize: 12,
    height: 1.4,
    color: color,
  );

  /// Material's text roles, so widgets that read `Theme.textTheme` follow
  /// the same scale.
  static TextTheme textTheme(Color primary, Color secondary) => TextTheme(
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
