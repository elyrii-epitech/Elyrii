/// Dimensions et espacements de l'application Elyrii
/// Définit toutes les valeurs de dimension pour maintenir la cohérence
class AppDimensions {
  AppDimensions._(); // Constructeur privé

  // ==================== ESPACEMENTS ====================
  
  /// Espacement minimal (4px)
  static const double spacingXxs = 4.0;
  
  /// Très petit espacement (8px)
  static const double spacingXs = 8.0;
  
  /// Petit espacement (12px)
  static const double spacingSm = 12.0;
  
  /// Espacement standard (16px)
  static const double spacingMd = 16.0;
  
  /// Grand espacement (24px)
  static const double spacingLg = 24.0;
  
  /// Très grand espacement (32px)
  static const double spacingXl = 32.0;
  
  /// Espacement extra large (48px)
  static const double spacingXxl = 48.0;
  
  /// Espacement géant (64px)
  static const double spacingXxxl = 64.0;

  // ==================== PADDING ====================
  
  /// Padding minimal pour les petits éléments
  static const double paddingXxs = 4.0;
  
  /// Padding très petit
  static const double paddingXs = 8.0;
  
  /// Padding petit
  static const double paddingSm = 12.0;
  
  /// Padding standard (par défaut)
  static const double paddingMd = 16.0;
  
  /// Padding large
  static const double paddingLg = 24.0;
  
  /// Padding très large
  static const double paddingXl = 32.0;
  
  /// Padding horizontal standard des pages
  static const double pageHorizontalPadding = 20.0;
  
  /// Padding vertical standard des pages
  static const double pageVerticalPadding = 16.0;

  // ==================== BORDER RADIUS ====================
  
  /// Rayon minimal (2px)
  static const double radiusXxs = 2.0;
  
  /// Très petit rayon (4px)
  static const double radiusXs = 4.0;
  
  /// Petit rayon (8px)
  static const double radiusSm = 8.0;
  
  /// Rayon standard (12px)
  static const double radiusMd = 12.0;
  
  /// Grand rayon (16px)
  static const double radiusLg = 16.0;
  
  /// Très grand rayon (24px)
  static const double radiusXl = 24.0;
  
  /// Rayon extra large (32px)
  static const double radiusXxl = 32.0;
  
  /// Rayon circulaire (1000px)
  static const double radiusCircular = 1000.0;

  // ==================== TAILLES D'ICÔNES ====================
  
  /// Très petite icône (12px)
  static const double iconXxs = 12.0;
  
  /// Petite icône (16px)
  static const double iconXs = 16.0;
  
  /// Icône petit-moyenne (20px)
  static const double iconSm = 20.0;
  
  /// Icône standard (24px)
  static const double iconMd = 24.0;
  
  /// Grande icône (32px)
  static const double iconLg = 32.0;
  
  /// Très grande icône (48px)
  static const double iconXl = 48.0;
  
  /// Icône extra large (64px)
  static const double iconXxl = 64.0;
  
  /// Icône géante (96px)
  static const double iconXxxl = 96.0;

  // ==================== HAUTEURS ====================
  
  /// Hauteur minimale des boutons
  static const double buttonHeightMin = 40.0;
  
  /// Hauteur standard des boutons
  static const double buttonHeight = 48.0;
  
  /// Hauteur des grands boutons
  static const double buttonHeightLarge = 56.0;
  
  /// Hauteur des champs de texte
  static const double inputHeight = 56.0;
  
  /// Hauteur de l'AppBar
  static const double appBarHeight = 56.0;
  
  /// Hauteur de la BottomNavigationBar
  static const double bottomNavHeight = 64.0;
  
  /// Hauteur des cartes simples
  static const double cardHeightSmall = 80.0;
  
  /// Hauteur des cartes moyennes
  static const double cardHeightMedium = 120.0;
  
  /// Hauteur des cartes grandes
  static const double cardHeightLarge = 200.0;

  // ==================== LARGEURS ====================
  
  /// Largeur maximale pour les petits écrans (smartphone)
  static const double maxWidthMobile = 480.0;
  
  /// Largeur maximale pour les tablettes
  static const double maxWidthTablet = 768.0;
  
  /// Largeur maximale pour les écrans desktop
  static const double maxWidthDesktop = 1200.0;
  
  /// Largeur maximale du contenu des pages
  static const double maxContentWidth = 600.0;

  // ==================== ÉLÉVATION (SHADOW) ====================
  
  /// Pas d'élévation
  static const double elevationNone = 0.0;
  
  /// Élévation minimale
  static const double elevationXs = 1.0;
  
  /// Élévation petite
  static const double elevationSm = 2.0;
  
  /// Élévation standard
  static const double elevationMd = 4.0;
  
  /// Élévation moyenne
  static const double elevationLg = 8.0;
  
  /// Élévation forte
  static const double elevationXl = 12.0;
  
  /// Élévation très forte
  static const double elevationXxl = 16.0;

  // ==================== BORDURES ====================
  
  /// Épaisseur de bordure fine
  static const double borderWidthThin = 1.0;
  
  /// Épaisseur de bordure standard
  static const double borderWidthMedium = 2.0;
  
  /// Épaisseur de bordure épaisse
  static const double borderWidthThick = 3.0;
  
  /// Épaisseur de bordure très épaisse
  static const double borderWidthExtraThick = 4.0;

  // ==================== TAILLES SPÉCIFIQUES ====================
  
  /// Taille de l'avatar petit
  static const double avatarSizeSmall = 32.0;
  
  /// Taille de l'avatar moyen
  static const double avatarSizeMedium = 48.0;
  
  /// Taille de l'avatar grand
  static const double avatarSizeLarge = 64.0;
  
  /// Taille de l'avatar très grand
  static const double avatarSizeXLarge = 96.0;
  
  /// Taille de l'avatar du profil
  static const double avatarSizeProfile = 120.0;
  
  /// Taille de la mascotte sur le dashboard
  static const double mascotSizeDashboard = 150.0;
  
  /// Taille de la mascotte en plein écran
  static const double mascotSizeFullscreen = 300.0;
  
  /// Hauteur de la bulle de message du chatbot
  static const double chatBubbleMaxWidth = 280.0;
  
  /// Hauteur minimale de la zone de saisie du chatbot
  static const double chatInputMinHeight = 56.0;
  
  /// Hauteur maximale de la zone de saisie du chatbot
  static const double chatInputMaxHeight = 120.0;
  
  /// Largeur de la carte d'objectif
  static const double objectiveCardWidth = 160.0;
  
  /// Hauteur de la carte d'objectif
  static const double objectiveCardHeight = 200.0;
  
  /// Taille du badge d'achievement
  static const double achievementBadgeSize = 80.0;
  
  /// Hauteur de la carte de méditation
  static const double meditationCardHeight = 140.0;
  
  /// Largeur de la barre de progression
  static const double progressBarHeight = 8.0;
  
  /// Largeur de la barre de progression épaisse
  static const double progressBarHeightThick = 12.0;

  // ==================== ANIMATIONS ====================
  
  /// Durée d'animation courte (en millisecondes)
  static const int animationDurationShort = 200;
  
  /// Durée d'animation standard (en millisecondes)
  static const int animationDurationMedium = 300;
  
  /// Durée d'animation longue (en millisecondes)
  static const int animationDurationLong = 500;
  
  /// Durée d'animation très longue (en millisecondes)
  static const int animationDurationXLong = 800;

  // ==================== DIVIDERS ====================
  
  /// Épaisseur du divider
  static const double dividerThickness = 1.0;
  
  /// Épaisseur du divider épais
  static const double dividerThicknessThick = 2.0;
  
  /// Indentation du divider
  static const double dividerIndent = 16.0;

  // ==================== OPACITY ====================
  
  /// Opacité désactivée
  static const double opacityDisabled = 0.38;
  
  /// Opacité moyenne
  static const double opacityMedium = 0.60;
  
  /// Opacité haute
  static const double opacityHigh = 0.87;
  
  /// Opacité pour les overlays
  static const double opacityOverlay = 0.04;

  // ==================== ASPECT RATIO ====================
  
  /// Ratio carré
  static const double aspectRatioSquare = 1.0;
  
  /// Ratio 16:9
  static const double aspectRatioWide = 16.0 / 9.0;
  
  /// Ratio 4:3
  static const double aspectRatioStandard = 4.0 / 3.0;
  
  /// Ratio 3:2
  static const double aspectRatioPhoto = 3.0 / 2.0;
}
