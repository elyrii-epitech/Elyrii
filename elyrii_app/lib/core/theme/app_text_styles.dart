import 'package:flutter/material.dart';

/// The only type scale of the app. Each role fixes size, weight and spacing,
/// so screens pick a role and never tune a style.
///
/// Les tailles, graisses, interlignes et espacements suivent la table
/// typographique v2 de l'Accueil. Les rôles dont l'interligne y est
/// « normal » n'imposent aucun facteur Flutter : la boîte naturelle de
/// Poppins s'applique.
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle _baseStyle = TextStyle(fontFamily: 'Poppins');

  static TextStyle _role(
    double size,
    FontWeight weight,
    double? height,
    double letterSpacing,
    Color? color,
  ) => _baseStyle.copyWith(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  /// The "elyrii" logotype on the launch screen: light and widely spaced.
  static TextStyle wordmark({Color? color}) =>
      _role(38, FontWeight.w500, 1.2, 3, color);

  /// Root page title, rendered by `ElyriiPageFrame` only.
  static TextStyle pageTitle({Color? color}) =>
      _role(28, FontWeight.w700, 1.1, -0.6, color);

  /// Auth and onboarding headings (t-headline).
  static TextStyle headlineMedium({Color? color}) =>
      _role(28, FontWeight.w700, 1.25, -0.5, color);

  /// The Série sheet headline, tighter than t-headline (interligne 1,1).
  static TextStyle streakHeadline({Color? color}) =>
      _role(28, FontWeight.w700, 1.1, -0.5, color);

  /// Stat numbers, hero values and large emoji (t-num).
  static TextStyle headlineSmall({Color? color}) =>
      _role(24, FontWeight.w700, 1.2, -0.3, color);

  /// Sheet and dialog titles (t-title-l).
  static TextStyle titleLarge({Color? color}) =>
      _role(20, FontWeight.w600, 1.3, -0.2, color);

  /// Section titles and card hero titles (t-title).
  static TextStyle titleMedium({Color? color}) =>
      _role(17, FontWeight.w700, 1.35, -0.2, color);

  /// Centered navigation titles, rendered by the page headers only.
  static TextStyle navTitle({Color? color}) =>
      _role(17, FontWeight.w600, 1.35, -0.1, color);

  /// The title of a bottom sheet (titre de feuille).
  static TextStyle sheetTitle({Color? color}) =>
      _role(17, FontWeight.w600, null, 0, color);

  /// Card and row titles (t-title-s).
  static TextStyle titleSmall({Color? color}) =>
      _role(15, FontWeight.w600, 1.4, 0, color);

  /// Reading text, inputs and chat messages (t-body-l).
  static TextStyle bodyLarge({Color? color}) =>
      _role(16, FontWeight.w400, 1.5, 0, color);

  /// Card bodies and quotes (t-body).
  static TextStyle bodyMedium({Color? color}) =>
      _role(14, FontWeight.w400, 1.45, 0, color);

  /// Secondary and meta text. Medium weight: 12 pt Regular strokes are too
  /// thin to keep secondary greys readable on glass (t-body-s).
  static TextStyle bodySmall({Color? color}) =>
      _role(12, FontWeight.w500, 1.35, 0, color);

  /// The composer question, entry excerpts and search notes (14/1.5).
  static TextStyle journalLine({Color? color}) =>
      _role(14, FontWeight.w400, 1.5, 0, color);

  /// A Journal entry read in full (16/1.7).
  static TextStyle readingBody({Color? color}) =>
      _role(16, FontWeight.w400, 1.7, 0, color);

  /// The body being written in the editor (16/1.75).
  static TextStyle writingBody({Color? color}) =>
      _role(16, FontWeight.w400, 1.75, 0, color);

  /// The date at the top of the editor (14/600).
  static TextStyle editorDate({Color? color}) =>
      _role(14, FontWeight.w600, null, 0, color);

  /// Small pills: « Privé », the month filter, the reading mood (12/600).
  static TextStyle pillLabel({Color? color}) =>
      _role(12, FontWeight.w600, null, 0, color);

  /// The writing prompt chip of the editor (12/500, interligne 1,5).
  static TextStyle promptChip({Color? color}) =>
      _role(12, FontWeight.w500, 1.5, 0, color);

  /// Button labels, and the default action of a dialog (bouton).
  static TextStyle labelLarge({Color? color}) =>
      _role(15, FontWeight.w600, null, 0.2, color);

  /// Small buttons of the answer card and the sheets (bouton petit).
  static TextStyle buttonSmall({Color? color}) =>
      _role(13, FontWeight.w600, null, 0.2, color);

  /// The other actions of a dialog, lighter than the default one.
  static TextStyle dialogAction({Color? color}) =>
      _role(15, FontWeight.w400, null, 0.2, color);

  /// Chips, short labels and small values (t-label-m, chip).
  static TextStyle labelMedium({Color? color}) =>
      _role(13, FontWeight.w600, null, 0, color);

  /// Section labels above a group, and the home date.
  static TextStyle overline({Color? color}) =>
      _role(13, FontWeight.w700, 1.2, 0.6, color);

  /// The date button of the top bar (date de la barre).
  static TextStyle navDate({Color? color}) =>
      _role(15, FontWeight.w600, null, 0, color);

  /// The counts of the streak/flowers/outfit capsule (valeurs de capsule).
  static TextStyle capsuleValue({Color? color}) =>
      _role(14, FontWeight.w600, null, 0, color);

  /// The words after each capsule count (suffixes « jours », « fleurs »).
  static TextStyle capsuleSuffix({Color? color}) =>
      _role(14, FontWeight.w500, null, 0, color);

  /// Mood face labels (labels d'humeur).
  static TextStyle moodLabel({Color? color}) =>
      _role(11, FontWeight.w500, null, 0, color);

  /// The selected mood face label, one weight up.
  static TextStyle moodLabelSelected({Color? color}) =>
      _role(11, FontWeight.w600, null, 0, color);

  /// A ritual tile title (titre rituel).
  static TextStyle ritualTitle({Color? color}) =>
      _role(13, FontWeight.w600, 1.25, 0, color);

  /// A ritual tile detail line (détail rituel).
  static TextStyle ritualDetail({Color? color}) =>
      _role(11, FontWeight.w500, null, 0, color);

  /// Captions and dock labels. 11 pt is the smallest text the app renders
  /// (t-caption).
  static TextStyle labelSmall({Color? color}) =>
      _role(11, FontWeight.w500, null, 0.4, color);

  static TextStyle gardenCaption({Color? color}) =>
      _role(12, FontWeight.w600, 1.35, 0, color);

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
