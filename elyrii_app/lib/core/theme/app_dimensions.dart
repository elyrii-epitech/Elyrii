/// Spacing, radii and sizes shared by every screen. Screens pick a step of
/// these scales and never write a raw distance.
class AppDimensions {
  AppDimensions._();

  static const double spacing2 = 2;
  static const double spacing4 = 4;
  static const double spacing8 = 8;
  static const double spacing12 = 12;
  static const double spacing16 = 16;
  static const double spacing20 = 20;
  static const double spacing24 = 24;
  static const double spacing32 = 32;
  static const double spacing48 = 48;

  static const double pageHorizontalPadding = spacing20;

  // ==================== RADII ====================

  static const double radius4 = 4;
  static const double radius8 = 8;
  static const double radius12 = 12;
  static const double radius16 = 16;

  /// Tuiles de rituels et boutons d'action de la réponse.
  static const double radius18 = 18;

  static const double radius20 = 20;

  /// Capsule Série/Fleurs/Tenue au repos.
  static const double radius26 = 26;

  /// Sheets and modal surfaces.
  static const double radius28 = 28;

  /// Panneau calendrier.
  static const double radius30 = 30;

  /// Feuilles Série, Fleurs et dressing.
  static const double radius38 = 38;

  static const double radiusPill = 999;

  static const double iconSm = 20;
  static const double iconMd = 24;

  /// Tap target of the glass buttons, and the width that balances them.
  static const double controlSize = 48;

  static const double buttonHeight = 48;
  static const double maxContentWidth = 600;

  static const double elevationSm = 2;
  static const double elevationMd = 4;
  static const double elevationLg = 8;
  static const double elevationXl = 12;

  static const double borderWidthThin = 1;
  static const double borderWidthMedium = 2;
  static const double dividerThickness = 1;

  // ==================== GÉOMÉTRIE ACCUEIL ====================

  /// Hauteur du décor derrière le héros (viewBox 390 × 470).
  static const double accueilSceneHeight = 470;

  /// Pixels de décor que la feuille de contenu recouvre à l'état repos.
  static const double accueilSheetOverlap = 32;

  /// Dépassement de la capsule au-dessus du bord de la feuille.
  static const double accueilCapsuleOverhang = 26;

  /// Hauteur de la capsule au repos, puis une fois épinglée.
  static const double accueilCapsuleHeight = 52;
  static const double accueilCapsuleCompactHeight = 44;

  /// Amplitude du hop de la mascotte (translateY -12 à mi-parcours).
  static const double accueilHopDistance = 12;

  /// Face d'humeur sélectionnée (diamètre visuel 54 pour un disque de 50).
  static const double accueilMoodFaceSelectedScale = 1.08;

  /// Pop d'essayage : la preview part de 0,94, culmine à 1,03, revient à 1.
  static const double accueilPreviewPopScale = 0.94;
  static const double accueilPreviewPopPeakScale = 1.03;

  static const double accueilBarHeight = 54;
  static const double accueilHeaderControl = 44;

  /// The 3D viewer frames the bear with margins, so its box is larger than
  /// the mockup's 230-pt image and starts higher to put the bear at the
  /// same place (top ≈ 102, feet ≈ 303 under the status bar).
  static const double accueilHeroTop = 46;
  static const double accueilHeroSize = 304;

  /// Distance from the viewer's bottom edge to the bear's feet.
  static const double accueilHeroFeetInset = 36;
  static const double accueilDressingHeroLift = 14;
  static const double accueilSheetTop = 384;
  static const double accueilCapsuleTop = 358;
  static const double accueilCapsulePinnedTop = 58;
  static const double accueilMoodFace = 50;
  static const double accueilSectionGap = 22;
  static const double accueilRiseDistance = 14;
  static const double accueilCalendarRiseDistance = 6;
  static const double accueilSheetTopPadding = 48;
  static const double accueilDressTop = 334;
  static const double dockHeight = 64;

  static double dockBottomMargin(double safeBottom) =>
      safeBottom > 0 ? spacing20 : spacing16;

  static double accessibleDockHeight(double scaledLabelHeight) =>
      spacing48 + scaledLabelHeight * 2;
}
