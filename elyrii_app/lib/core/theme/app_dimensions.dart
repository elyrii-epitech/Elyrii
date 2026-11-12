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

  static const double radius4 = 4;
  static const double radius8 = 8;
  static const double radius12 = 12;
  static const double radius16 = 16;

  /// Ritual tiles and response action buttons.
  static const double radius18 = 18;

  static const double radius20 = 20;

  /// Streak/flowers/outfit capsule at rest.
  static const double radius26 = 26;

  /// Sheets and modal surfaces.
  static const double radius28 = 28;

  /// Calendar panel.
  static const double radius30 = 30;

  /// Streak, flowers, and dressing-room sheets.
  static const double radius38 = 38;

  static const double radiusPill = 999;

  /// Sheet grabber (36 × 5).
  static const double grabberWidth = 36;
  static const double grabberHeight = 5;

  /// Journal writing prompt chip.
  static const double radius14 = 14;

  /// Glass toolbar of the Journal editor.
  static const double radius24 = 24;

  static const double iconSm = 20;
  static const double iconXs = 14;
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

  /// Scene height behind the hero, with a 390 × 470 viewBox.
  static const double accueilSceneHeight = 470;

  /// Scene pixels covered by the content sheet at rest.
  static const double accueilSheetOverlap = 32;

  /// Capsule overlap above the sheet edge.
  static const double accueilCapsuleOverhang = 26;

  /// Capsule height at rest, then when pinned.
  static const double accueilCapsuleHeight = 52;
  static const double accueilCapsuleCompactHeight = 44;

  /// Mascot hop amplitude: translateY -12 at the midpoint.
  static const double accueilHopDistance = 12;

  /// Selected mood face: visual diameter 54 for a 50-point disc.
  static const double accueilMoodFaceSelectedScale = 1.08;

  /// Outfit preview pop: starts at 0.94, peaks at 1.03, returns to 1.
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
  static const double dockIcon = 23;
  static const double dockAvatar = 44;
  static const double dockItemGap = 1;
  static const double dockItemPadding = 5;
  static const double dockItemHeight = 48;
  static const double dockItemWidth = 58;
  static const double dockMinWidth = 360;
  static const double dockMaxLabelSize = 13.2;
  static const double glassStroke = 0.5;
  static const double navigationBlur = 22;
  static const double navigationSaturation = 1.7;

  static const double sectionSkyHeight = 290;
  static const double sectionBodyOverlap = 30;
  static const double sectionTitleBottom = 48;
  static const double sectionScrollThreshold = 190;
  static const double sectionPeriodTop = 112;
  static const double gardenTouchPadding = 6;
  static const double gardenCalendarMinWidth = 350;
  static const double gardenGap = 6;
  static const double gardenPlotHeight = 37;
  static const double gardenPlotInset = (controlSize - gardenPlotHeight) / 2;
  static const double gardenWeekPlotHeight = 62;
  static const double gardenPlotRadius = 9;
  static const double gardenFlowerSize = 27;
  static const double gardenRewardWidth = 158;
  static const double gardenRewardHeight = 84;
  static const double gardenPreviewHeight = 208;
  static const double gardenBloomSize = 112;

  /// Day stamp column; the thread runs at [journalThreadInset] from the left.
  static const double journalDayColumn = 49;
  static const double journalThreadInset = 24;
  static const double journalThreadTop = 12;
  static const double journalThreadBottom = 36;
  static const double journalMonthGap = 40;

  /// Round tools of the composer, filters and the editor close button.
  static const double journalTool = 36;
  static const double journalRefresh = 30;
  static const double journalMoodDot = 8;
  static const double journalFilterDot = 12;
  static const double journalPill = 24;
  static const double journalSquare = 32;
  static const double journalSquareRadius = 9;
  static const double journalShield = 44;
  static const double journalRowHeight = 56;
  static const double journalPromptRowHeight = 58;
  static const double journalBigButton = 50;
  static const double journalMoodColumn = 58;
  static const double journalMascotWidth = 94;
  static const double journalMascotHeight = 114;
  static const double journalBodyMinHeight = 220;
  static const double journalToastTop = 112;
  static const double journalSearchField = 40;

  static const double meditationChipHeight = 36;
  static const double meditationFeaturedHeight = 200;
  static const double meditationTileSize = 142;
  static const double meditationTileRadius = 21;
  static const double meditationRowHeight = 67;
  static const double meditationCircle = 248;
  static const double meditationCircleMinScale = .84;

  /// The viewer includes framing margins around the 150 × 180 visual bear.
  static const double meditationMascotWidth = 300;
  static const double meditationMascotHeight = 360;
  static const double meditationSessionTop = 64;
  static const double meditationPhaseGap = 38;
  static const double meditationProgressHeight = 6;
  static const double meditationButtonHeight = 50;
  static const double meditationIcon = 28;
  static const double meditationBandIcon = 38;
  static const double meditationPreviewWidth = 360;
  static const double meditationFeaturedArtWidth = 190;
  static const double meditationFeaturedArtHeight = 170;

  static const double profileTop = 94;
  static const double profileAvatar = 96;

  /// Home scene drawn at its own scale and raised so the moon clears the back
  /// button while the ground remains visible above the Profile body.
  static const double profileSceneLift = 80;
  static const double profileEditAvatar = 64;
  static const double profileAvatarPreview = 120;
  static const double profileAvatarTile = 66;
  static const double profileFieldLabel = 86;
  static const double profileBioHeight = 80;
  static const double profileRowHeight = 56;
  static const double profileSquare = 32;
  static const double profileSquareRadius = 9;
  static const double profileIcon = 19;
  static const double profileSegment = 36;
  static const double profileToggleWidth = 51;
  static const double profileToggleHeight = 31;
  static const double profileToggleThumb = 27;
  static const double profileToggleTravel = 20;
  static const double profileChartHeight = 95;
  static const double profileChartPlot = 77;
  static const double profileMoodDot = 13;
  static const double profileMoodStep = 15;
  static const double profileBarChart = 60;
  static const double profileBarHeight = 43;
  static const double profileBarWidth = 16;
  static const double profileChartIcon = 28;
  static const double profileHairline = .5;

  static const double arrivalSceneHeight = 360;
  static const double arrivalSheetTop = 326;
  static const double arrivalHeroTop = 56;
  static const double arrivalHeroSize = 270;
  static const double arrivalLaunchHero = 360;
  static const double arrivalLaunchTop = 190;
  static const double arrivalWordTop = 552;
  static const double arrivalResetTop = 120;
  static const double arrivalPalette = 42;
  static const double arrivalDecorHeight = 50;
  static const double arrivalMinBody = 520;
  static const double arrivalProgressHeight = 4;
  static const double arrivalHeroFadeRange = 260;
  static const double arrivalAuthThreshold = 240;
  static const double arrivalStepThreshold = 220;
  static const double arrivalGoalThreshold = 80;

  static const double sheetDismissFraction = .25;
  static const double sheetDismissVelocity = 700;

  static double dockBottomMargin(double safeBottom) => spacing20;

  static double accessibleDockHeight(double scaledLabelHeight) =>
      spacing48 + scaledLabelHeight * 2;
}
