/// Spacing, radii and sizes shared by every screen. Screens pick a step of
/// these scales and never write a raw distance.
class AppDimensions {
  AppDimensions._();

  // ==================== SPACING (4 pt grid) ====================

  static const double spacing2 = 2;
  static const double spacing4 = 4;
  static const double spacing8 = 8;
  static const double spacing12 = 12;
  static const double spacing16 = 16;
  static const double spacing20 = 20;
  static const double spacing24 = 24;
  static const double spacing32 = 32;
  static const double spacing48 = 48;

  /// Horizontal inset of every page.
  static const double pageHorizontalPadding = spacing20;

  // ==================== RADII ====================

  static const double radius4 = 4;
  static const double radius8 = 8;
  static const double radius12 = 12;
  static const double radius16 = 16;
  static const double radius20 = 20;

  /// Sheets and modal surfaces.
  static const double radius28 = 28;

  /// Capsules and circles.
  static const double radiusPill = 999;

  // ==================== SIZES ====================

  static const double iconSm = 20;
  static const double iconMd = 24;

  /// Tap target of the glass buttons, and the width that balances them.
  static const double controlSize = 48;

  static const double buttonHeight = 48;
  static const double maxContentWidth = 600;

  // ==================== ELEVATION ====================

  static const double elevationSm = 2;
  static const double elevationMd = 4;
  static const double elevationLg = 8;
  static const double elevationXl = 12;

  // ==================== BORDERS ====================

  static const double borderWidthThin = 1;
  static const double borderWidthMedium = 2;
  static const double dividerThickness = 1;
}
