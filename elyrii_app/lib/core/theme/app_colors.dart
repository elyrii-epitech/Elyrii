import 'package:flutter/material.dart';

/// Palette de couleurs de l'application Elyrii
/// Définit toutes les couleurs utilisées dans l'application pour maintenir la cohérence visuelle
class AppColors {
  AppColors._(); // Constructeur privé pour empêcher l'instanciation

  // ==================== COULEURS PRINCIPALES ====================

  /// Couleur principale de l'application (violet brillant et glossy)
  /// Base: #8B6FF0 → Light: #9D7FFE (plus brillant et saturé)
  /// Dark: #B99CFF - Violet glossy très lumineux
  static const Color primary = Color(0xFF9D7FFE);
  static const Color primaryLight =
      Color(0xFFEBE3FF); // Lavande glossy très pâle
  static const Color primaryDark =
      Color(0xFFB99CFF); // Violet glossy très lumineux (dark mode)

  /// Couleur secondaire (pêche rosé chaleureux)
  /// Light: #FFB5A8 - Pêche doux
  /// Dark: #FFCCBF - Pêche très pâle
  static const Color secondary = Color(0xFFFFB5A8);
  static const Color secondaryLight = Color(0xFFFFE4DD);
  static const Color secondaryDark =
      Color(0xFFFFCCBF); // Pêche pâle (dark mode)

  /// Couleur d'accent (menthe douce)
  static const Color accent = Color(0xFFA8D5BA);
  static const Color accentLight = Color(0xFFD4EFE0);
  static const Color accentDark = Color(0xFFC2E3D2);



  // ==================== COULEURS SÉMANTIQUES ====================

  /// Couleurs douces pour les états de succès, erreur, warning, info
  static const Color success = Color(0xFF7BC393);
  static const Color successLight = Color(0xFFCBEDD8);
  static const Color successDark = Color(0xFF5FA87A);

  static const Color error = Color(0xFFEA9999);
  static const Color errorLight = Color(0xFFF5CCCC);
  static const Color errorDark = Color(0xFFD77F7F);

  static const Color warning = Color(0xFFFFCFA8);
  static const Color warningLight = Color(0xFFFFE7D1);
  static const Color warningDark = Color(0xFFFFB888);

  static const Color info = Color(0xFF93B8DA);
  static const Color infoLight = Color(0xFFD1E4F3);
  static const Color infoDark = Color(0xFF7AA3C7);

  // ==================== COULEURS NEUTRES - LIGHT MODE ====================

  /// Light Theme: Tons chauds et apaisants
  static const Color backgroundLight =
      Color(0xFFFAF8F5); // Beige très clair chaleureux
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFF5F2EF); // Crème doux

  static const Color textPrimaryLight = Color(0xFF3D3A38);
  static const Color textSecondaryLight = Color(0xFF766F6A);
  static const Color textTertiaryLight = Color(0xFFA39C96);

  static const Color dividerLight = Color(0xFFE8E3DD);
  static const Color borderLight = Color(0xFFD9D2CC);
  static const Color shadowLight = Color(0x1A3D3A38);

  // ==================== COULEURS NEUTRES - DARK MODE ====================

  /// Dark Theme: Tons sombres chauds et confortables
  static const Color backgroundDark = Color(0xFF1A1818); // Noir chocolat
  static const Color surfaceDark = Color(0xFF2A2627); // Brun très foncé
  static const Color cardDark = Color(0xFF352F31); // Brun foncé

  static const Color textPrimaryDark = Color(0xFFF5F3F0);
  static const Color textSecondaryDark = Color(0xFFCCC5BF);
  static const Color textTertiaryDark = Color(0xFFA39C96);

  static const Color dividerDark = Color(0xFF453F3C);
  static const Color borderDark = Color(0xFF554E4A);
  static const Color shadowDark = Color(0x33000000);

  // ==================== COULEURS SPÉCIFIQUES ====================

  /// Couleurs pour la gamification
  static const Color xpBar = Color(0xFFFDD876); // Jaune miel doux
  static const Color levelBadge = Color(0xFF9D7FFE); // Violet brillant glossy
  static const Color streak = Color(0xFFFFB5A8); // Pêche doux

  /// Couleurs pour les objectifs
  static const Color objectiveCompleted = Color(0xFF7BC393);
  static const Color objectiveInProgress =
      Color(0xFF9D7FFE); // Violet brillant glossy
  static const Color objectiveNotStarted = Color(0xFFBFC5D1);

  /// Couleurs pour la méditation
  static const Color meditationActive =
      Color(0xFF9D7FFE); // Violet brillant glossy
  static const Color meditationBreathing =
      Color(0xFFB99CFF); // Violet glossy très lumineux

  /// Gradient pour le chatbot
  static const LinearGradient chatbotGradient = LinearGradient(
    colors: [
      Color(0xFF9D7FFE),
      Color(0xFFB99CFF)
    ], // Violet brillant glossy -> Violet très lumineux
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Gradient pour les cartes importantes
  static const LinearGradient cardGradient = LinearGradient(
    colors: [
      Color(0xFFFAF8F5),
      Color(0xFFEBE3FF)
    ], // Beige clair -> Lavande glossy très pâle
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ==================== COULEURS OVERLAY ====================

  /// Overlays pour les états interactifs
  static const Color overlay = Color(0x0A000000);
  static const Color overlayPressed = Color(0x14000000);
  static const Color overlayFocused = Color(0x1F000000);
  static const Color overlayHovered = Color(0x0A000000);

  /// Overlay pour les modals/dialogs
  static const Color scrim = Color(0x80000000);
}
