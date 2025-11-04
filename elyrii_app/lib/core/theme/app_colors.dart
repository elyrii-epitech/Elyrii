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
  static const Color primaryLight = Color(0xFFEBE3FF); // Lavande glossy très pâle
  static const Color primaryDark = Color(0xFFB99CFF); // Violet glossy très lumineux (dark mode)
  
  /// Couleur secondaire (pêche rosé chaleureux)
  /// Light: #FFB5A8 - Pêche doux
  /// Dark: #FFCCBF - Pêche très pâle
  static const Color secondary = Color(0xFFFFB5A8);
  static const Color secondaryLight = Color(0xFFFFE4DD);
  static const Color secondaryDark = Color(0xFFFFCCBF); // Pêche pâle (dark mode)
  
  /// Couleur d'accent (menthe douce)
  static const Color accent = Color(0xFFA8D5BA);
  static const Color accentLight = Color(0xFFD4EFE0);
  static const Color accentDark = Color(0xFFC2E3D2);

  // ==================== COULEURS ÉMOTIONNELLES ====================
  
  /// Couleurs douces pour représenter les émotions dans le journal
  static const Color emotionJoy = Color(0xFFFDD876); // Jaune miel doux
  static const Color emotionSad = Color(0xFF93B8DA); // Bleu ciel apaisant
  static const Color emotionAnxiety = Color(0xFFFFCFA8); // Orange crème
  static const Color emotionCalm = Color(0xFFA8D5BA); // Vert menthe doux
  static const Color emotionAngry = Color(0xFFEA9999); // Rouge rosé doux
  static const Color emotionNeutral = Color(0xFFBFC5D1); // Gris perle
  static const Color emotionExcited = Color(0xFFFFB5D8); // Rose poudré
  static const Color emotionTired = Color(0xFFC5B8D5); // Lavande grisée

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
  static const Color backgroundLight = Color(0xFFFAF8F5); // Beige très clair chaleureux
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
  static const Color objectiveInProgress = Color(0xFF9D7FFE); // Violet brillant glossy
  static const Color objectiveNotStarted = Color(0xFFBFC5D1);
  
  /// Couleurs pour la méditation
  static const Color meditationActive = Color(0xFF9D7FFE); // Violet brillant glossy
  static const Color meditationBreathing = Color(0xFFB99CFF); // Violet glossy très lumineux
  
  /// Gradient pour le chatbot
  static const LinearGradient chatbotGradient = LinearGradient(
    colors: [Color(0xFF9D7FFE), Color(0xFFB99CFF)], // Violet brillant glossy -> Violet très lumineux
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  /// Gradient pour les cartes importantes
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFAF8F5), Color(0xFFEBE3FF)], // Beige clair -> Lavande glossy très pâle
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
