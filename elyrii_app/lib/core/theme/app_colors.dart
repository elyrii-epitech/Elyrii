import 'package:flutter/material.dart';

/// Palette de couleurs de l'application Elyrii
/// Définit toutes les couleurs utilisées dans l'application pour maintenir la cohérence visuelle
class AppColors {
  AppColors._(); // Constructeur privé pour empêcher l'instanciation

  // ==================== COULEURS PRINCIPALES ====================
  
  /// Couleur principale de l'application (violet/lavande apaisant)
  static const Color primary = Color(0xFF8B7FC7);
  static const Color primaryLight = Color(0xFFB8AEE8);
  static const Color primaryDark = Color(0xFF6B5FA3);
  
  /// Couleur secondaire (vert menthe doux)
  static const Color secondary = Color(0xFF7EC8A3);
  static const Color secondaryLight = Color(0xFFA8E3C5);
  static const Color secondaryDark = Color(0xFF5FA885);
  
  /// Couleur d'accent (rose poudré)
  static const Color accent = Color(0xFFE8A5C4);
  static const Color accentLight = Color(0xFFF5C9DC);
  static const Color accentDark = Color(0xFFD17FA5);

  // ==================== COULEURS ÉMOTIONNELLES ====================
  
  /// Couleurs pour représenter les émotions dans le journal
  static const Color emotionJoy = Color(0xFFFFC857); // Jaune joyeux
  static const Color emotionSad = Color(0xFF6B9BD1); // Bleu mélancolique
  static const Color emotionAnxiety = Color(0xFFE8A87C); // Orange anxiété
  static const Color emotionCalm = Color(0xFF7EC8A3); // Vert calme
  static const Color emotionAngry = Color(0xFFE56B6F); // Rouge colère
  static const Color emotionNeutral = Color(0xFFB0B8C1); // Gris neutre
  static const Color emotionExcited = Color(0xFFFF8FA3); // Rose excitation
  static const Color emotionTired = Color(0xFF9B8E9F); // Violet fatigue

  // ==================== COULEURS SÉMANTIQUES ====================
  
  /// Couleurs pour les états de succès, erreur, warning, info
  static const Color success = Color(0xFF5FCF80);
  static const Color successLight = Color(0xFFB8F2C7);
  static const Color successDark = Color(0xFF3BA55C);
  
  static const Color error = Color(0xFFE85D75);
  static const Color errorLight = Color(0xFFF5A3B3);
  static const Color errorDark = Color(0xFFD13A52);
  
  static const Color warning = Color(0xFFFFB347);
  static const Color warningLight = Color(0xFFFFD89B);
  static const Color warningDark = Color(0xFFE89A2E);
  
  static const Color info = Color(0xFF6EBAFF);
  static const Color infoLight = Color(0xFFB3DCFF);
  static const Color infoDark = Color(0xFF4A9FE8);

  // ==================== COULEURS NEUTRES - LIGHT MODE ====================
  
  static const Color backgroundLight = Color(0xFFFAF9FC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFF5F3F7);
  
  static const Color textPrimaryLight = Color(0xFF2D2633);
  static const Color textSecondaryLight = Color(0xFF6B6475);
  static const Color textTertiaryLight = Color(0xFF9E98A7);
  
  static const Color dividerLight = Color(0xFFE8E3ED);
  static const Color borderLight = Color(0xFFD1CAD9);
  static const Color shadowLight = Color(0x1A2D2633);

  // ==================== COULEURS NEUTRES - DARK MODE ====================
  
  static const Color backgroundDark = Color(0xFF1A1625);
  static const Color surfaceDark = Color(0xFF252131);
  static const Color cardDark = Color(0xFF2F2B3A);
  
  static const Color textPrimaryDark = Color(0xFFF5F3F7);
  static const Color textSecondaryDark = Color(0xFFB8B3BE);
  static const Color textTertiaryDark = Color(0xFF8A8591);
  
  static const Color dividerDark = Color(0xFF3A3642);
  static const Color borderDark = Color(0xFF4A4551);
  static const Color shadowDark = Color(0x33000000);

  // ==================== COULEURS SPÉCIFIQUES ====================
  
  /// Couleurs pour la gamification
  static const Color xpBar = Color(0xFFFFD93D);
  static const Color levelBadge = Color(0xFF8B7FC7);
  static const Color streak = Color(0xFFFF6B6B);
  
  /// Couleurs pour les objectifs
  static const Color objectiveCompleted = Color(0xFF5FCF80);
  static const Color objectiveInProgress = Color(0xFF6EBAFF);
  static const Color objectiveNotStarted = Color(0xFFB0B8C1);
  
  /// Couleurs pour la méditation
  static const Color meditationActive = Color(0xFF7EC8A3);
  static const Color meditationBreathing = Color(0xFF8B7FC7);
  
  /// Gradient pour le chatbot
  static const LinearGradient chatbotGradient = LinearGradient(
    colors: [Color(0xFF8B7FC7), Color(0xFFB8AEE8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  /// Gradient pour les cartes importantes
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFAF9FC), Color(0xFFF5F3F7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ==================== COULEURS SCAFFOLD ====================

  /// Fond de scaffold adapté au thème
  static const Color scaffoldLight = Color(0xFFE8E8EB);
  static const Color scaffoldDark = Color(0xFF171719);

  // ==================== COULEURS GLASSMORPHISM ====================

  /// Glass backgrounds - Light mode
  static const Color glassBackgroundLight = Color(0xD9FFFFFF); // 85% opacity
  static const Color glassBackgroundLightEnd = Color(0x99FFFFFF); // 60% opacity

  /// Glass backgrounds - Dark mode
  static const Color glassBackgroundDark = Color(0x1AFFFFFF); // 10% opacity
  static const Color glassBackgroundDarkEnd = Color(0x0DFFFFFF); // 5% opacity

  /// Glass borders
  static const Color glassBorderLight = Color(0x99FFFFFF); // 60% opacity
  static const Color glassBorderDark = Color(0x1FFFFFFF); // 12% opacity

  /// Couleurs lavande pour effets spéciaux
  static const Color glassLavender = Color(0xFFF5F3FF);
  static const Color glassLavenderBorder = Color(0xFFE0D4FF);

  // ==================== iOS 26 LIQUID GLASS ====================

  /// Liquid Glass backgrounds - Light mode (iOS 26)
  /// Opacités réduites pour plus de transparence "liquide"
  static const Color liquidGlassBackgroundLight =
      Color(0xB3FFFFFF); // 70% opacity
  static const Color liquidGlassBackgroundLightEnd =
      Color(0x80FFFFFF); // 50% opacity

  /// Liquid Glass backgrounds - Dark mode (iOS 26)
  /// Opacités augmentées pour meilleure lisibilité
  static const Color liquidGlassBackgroundDark =
      Color(0x2EFFFFFF); // 18% opacity
  static const Color liquidGlassBackgroundDarkEnd =
      Color(0x1FFFFFFF); // 12% opacity

  /// Liquid Glass borders (iOS 26)
  static const Color liquidGlassBorderLight = Color(0x66FFFFFF); // 40% opacity
  static const Color liquidGlassBorderDark = Color(0x40FFFFFF); // 25% opacity

  /// Specular highlight pour liquid glass (reflet en haut)
  static const Color liquidGlassSpecular = Color(0x14FFFFFF); // 8% opacity
  static const Color liquidGlassSpecularLight =
      Color(0x14FFFFFF); // 8% opacity - Light mode
  static const Color liquidGlassSpecularDark =
      Color(0x0AFFFFFF); // 4% opacity - Dark mode
  static const Color liquidGlassSpecularStrong =
      Color(0x1FFFFFFF); // 12% opacity

  /// Inner glow pour liquid glass
  static const Color liquidGlassInnerGlow = Color(0x0AFFFFFF); // 4% opacity

  /// Tint adaptatif (pour gradient adaptatif au background)
  static const Color liquidGlassTint =
      Color(0x08000000); // 3% opacity - blend subtil

  // ==================== COULEURS ICÔNES NAVIGATION ====================

  /// Icônes par défaut dans la navigation
  static const Color iconDefaultLight = Color(0xFF3A3A3D);
  static const Color iconDefaultDark = Color(0xFFE6E5E2);

  // ==================== COULEURS OVERLAY ====================
  
  /// Overlays pour les états interactifs
  static const Color overlay = Color(0x0A000000);
  static const Color overlayPressed = Color(0x14000000);
  static const Color overlayFocused = Color(0x1F000000);
  static const Color overlayHovered = Color(0x0A000000);
  
  /// Overlay pour les modals/dialogs
  static const Color scrim = Color(0x80000000);
  
  // ==================== HELPERS ====================
  
  /// Retourne la couleur associée à une émotion
  static Color getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'joy':
      case 'joyeux':
      case 'heureux':
        return emotionJoy;
      case 'sad':
      case 'triste':
        return emotionSad;
      case 'anxiety':
      case 'anxieux':
      case 'anxiété':
        return emotionAnxiety;
      case 'calm':
      case 'calme':
        return emotionCalm;
      case 'angry':
      case 'colère':
      case 'énervé':
        return emotionAngry;
      case 'excited':
      case 'excité':
        return emotionExcited;
      case 'tired':
      case 'fatigué':
        return emotionTired;
      default:
        return emotionNeutral;
    }
  }
  
  /// Retourne une liste de toutes les couleurs d'émotions
  static List<Color> get allEmotionColors => [
        emotionJoy,
        emotionSad,
        emotionAnxiety,
        emotionCalm,
        emotionAngry,
        emotionNeutral,
        emotionExcited,
        emotionTired,
      ];
}
