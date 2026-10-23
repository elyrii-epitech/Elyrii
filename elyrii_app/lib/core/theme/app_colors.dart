import 'package:flutter/material.dart';

/// Palette de couleurs de l'application Elyrii.
/// Définit toutes les couleurs utilisées dans l'application pour maintenir la cohérence visuelle.
/// Les valeurs neutres viennent des jetons v2 de l'Accueil : bg, label,
/// label-2, label-3, tint, surface, surface-2, stroke, separator, glass,
/// glass-stroke, track et thumb, en sombre et en clair. Les couleurs
/// translucides conservent leur alpha.
class AppColors {
  AppColors._(); // Constructeur privé pour empêcher l'instanciation

  // ==================== COULEURS PRINCIPALES ====================

  /// Couleur principale de l'application (tint clair).
  /// Lavande apaisée, utilisée comme accent plutôt que comme ambiance dominante.
  static const Color primary = Color(0xFF6050A5);
  static const Color primaryLight = Color(0xFFEDE8FF); // Lavande très pâle
  static const Color primaryDark = Color(
    0xFFA99AF0,
  ); // Tint sombre, lisible en dark mode

  /// Couleur secondaire (pêche rosé chaleureux)
  /// Light: #FFB5A8 - Pêche doux
  /// Dark: #FFCCBF - Pêche très pâle
  static const Color secondary = Color(0xFFFFB5A8);
  static const Color secondaryLight = Color(0xFFFFE4DD);
  static const Color secondaryDark = Color(
    0xFFFFCCBF,
  ); // Pêche pâle (dark mode)

  /// Couleur d'accent (menthe douce)
  static const Color accent = Color(0xFFA8D5BA);
  static const Color accentLight = Color(0xFFD4EFE0);
  static const Color accentDark = Color(0xFFC2E3D2);

  // ==================== COULEURS SÉMANTIQUES ====================

  /// Couleurs douces pour les états de succès, erreur, warning, info
  static const Color success = Color(0xFF7BC393);
  static const Color successLight = Color(0xFFCBEDD8);
  static const Color successDark = Color(0xFF5FA87A);

  static const Color error = Color(0xFFA73550);
  static const Color errorLight = Color(0xFFF5CCCC);
  static const Color errorDark = Color(0xFFFFB4AB);

  static Color successText(bool isDark) =>
      isDark ? const Color(0xFF8DD5A8) : const Color(0xFF286B41);
  static Color errorText(bool isDark) => isDark ? errorDark : error;
  static Color primaryText(bool isDark) => isDark ? primaryDark : primary;

  /// Tint du jour : texte et icônes posés sur une surface tintée.
  static Color onTint(bool isDark) =>
      isDark ? const Color(0xFF1B1530) : Colors.white;

  /// Aplat translucide du tint (tint-soft) pour les actions secondaires.
  static Color tintSoft(bool isDark) =>
      isDark ? const Color(0x29A99AF0) : const Color(0x1A6050A5);

  /// Bornes des contrôles activables, distinctes des surfaces.
  static const Color controlOutlineLight = Color(0xFF6B6481);
  static const Color controlOutlineDark = Color(0xFFA49DBB);
  static Color controlOutline(bool isDark) =>
      isDark ? controlOutlineDark : controlOutlineLight;

  /// Rail (track) et pouce (thumb) des commutateurs v2.
  static Color track(bool isDark) =>
      isDark ? const Color(0x3D767680) : const Color(0x1F767680);
  static Color thumb(bool isDark) =>
      isDark ? const Color(0xFF5C5670) : Colors.white;

  static const Color warning = Color(0xFFFFCFA8);
  static const Color warningLight = Color(0xFFFFE7D1);
  static const Color warningDark = Color(0xFFFFB888);

  static const Color info = Color(0xFF93B8DA);
  static const Color infoLight = Color(0xFFD1E4F3);
  static const Color infoDark = Color(0xFF7AA3C7);

  // ==================== COULEURS DE SECTION V2 ====================

  /// Six teintes de section, dont les cinq humeurs de l'Accueil.
  /// Sombre d'abord, clair ensuite, comme les autres rôles.
  static const Color orangeDark = Color(0xFFE76418);
  static const Color orangeLight = Color(0xFFE76418);
  static const Color greenDark = Color(0xFF43C97E);
  static const Color greenLight = Color(0xFF22A863);
  static const Color yellowDark = Color(0xFFFFC94D);
  static const Color yellowLight = Color(0xFFE8A800);
  static const Color tealDark = Color(0xFF3EC1E0);
  static const Color tealLight = Color(0xFF139CC4);
  static const Color pinkDark = Color(0xFFFF7A9C);
  static const Color pinkLight = Color(0xFFE5527A);
  static const Color violetDark = Color(0xFF8F7CF5);
  static const Color violetLight = Color(0xFF6E5BD8);

  static Color orange(bool isDark) => isDark ? orangeDark : orangeLight;
  static Color green(bool isDark) => isDark ? greenDark : greenLight;
  static Color yellow(bool isDark) => isDark ? yellowDark : yellowLight;
  static Color teal(bool isDark) => isDark ? tealDark : tealLight;
  static Color pink(bool isDark) => isDark ? pinkDark : pinkLight;
  static Color violet(bool isDark) => isDark ? violetDark : violetLight;

  static Color sectionBody(bool dark) =>
      dark ? const Color(0xFF15121F) : const Color(0xFFF4F3F8);
  static Color sectionSky(bool dark) =>
      dark ? const Color(0xFF1B1538) : const Color(0xFFE9E4FB);
  static Color gardenBoard(bool dark) =>
      dark ? const Color(0xFF23794D) : const Color(0xFFE3F4EA);
  static Color gardenBorder(bool dark) =>
      dark ? const Color(0xFF399A68) : borderLight;
  static Color gardenPlot(bool dark) =>
      dark ? const Color(0xFF1C5C3C) : Colors.white;
  static Color gardenEmptyPlot(bool dark) =>
      dark ? const Color(0xFF1B5538) : const Color(0x8CFFFFFF);
  static Color gardenInk(bool dark) =>
      dark ? Colors.white : const Color(0xFF173B26);
  static Color gardenNote(bool dark) =>
      dark ? const Color(0xFFA9DEBE) : const Color(0xFF1E7B49);
  static Color gardenGroup(bool dark) =>
      dark ? const Color(0xFF192D29) : surfaceLight;
  static Color gardenReward(bool dark) =>
      dark ? const Color(0xFF213329) : surfaceLight;
  static Color gardenRewardThumb(bool dark) =>
      dark ? const Color(0xFF315B40) : const Color(0xFFE3F4EA);

  /// The 3114 help line: pink in dark, a deeper rose that keeps 4.5:1 on
  /// the light soft-pink card.
  static Color helpInk(bool isDark) =>
      isDark ? pinkDark : const Color(0xFFBC4159);

  /// label-2 et label-3 exacts du spec, translucides. label-3 n'atteint pas
  /// 4,5:1 sur un petit texte : il sert au texte large et au décoratif, les
  /// rôles textSecondary/textTertiary opaques gardent le texte courant.
  static Color label2(bool isDark) =>
      isDark ? const Color(0xA3ECE9F5) : const Color(0x9E1C1A24);
  static Color label3(bool isDark) =>
      isDark ? const Color(0x6BECE9F5) : const Color(0x6B1C1A24);

  // ==================== COULEURS NEUTRES - LIGHT MODE ====================

  /// Light Theme: encre violette (#1C1A24) sur un fond #F3F2F8.
  static const Color backgroundLight = Color(0xFFF3F2F8);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFECEAF3); // surface-2

  static const Color textPrimaryLight = Color(0xFF1C1A24); // label
  static const Color textSecondaryLight = Color(0xFF4A4560);
  static const Color textTertiaryLight = Color(0xFF57516B);

  static const Color dividerLight = Color(0x171C1A24); // separator, 9 %
  static const Color borderLight = Color(0x0F1C1A24); // stroke, 6 %
  static const Color shadowLight = Color(0x1A1E1A2B);

  // ==================== COULEURS NEUTRES - DARK MODE ====================

  /// Dark Theme: nuit violette (#0D0B13), jamais un noir neutre.
  static const Color backgroundDark = Color(0xFF0D0B13);
  static const Color surfaceDark = Color(0x0EFFFFFF); // surface, 5,5 %
  static const Color cardDark = Color(0x17FFFFFF); // surface-2, 9 %

  static const Color textPrimaryDark = Color(0xFFF4F2F8); // label
  static const Color textSecondaryDark = Color(0xFFC8C2DA);
  static const Color textTertiaryDark = Color(0xFFA49DBB);

  static const Color dividerDark = Color(0x14FFFFFF); // separator, 8 %
  static const Color borderDark = Color(0x12FFFFFF); // stroke, 7 %
  static const Color shadowDark = Color(0x33000000);

  // ==================== COULEURS SPÉCIFIQUES ====================

  /// Couleurs pour la gamification
  static const Color xpBar = Color(0xFFFDD876); // Jaune miel doux
  static const Color levelBadge = Color(0xFF7E6AD8);
  static const Color streak = Color(0xFFFFB5A8); // Pêche doux

  /// Couleurs pour les objectifs
  static const Color objectiveCompleted = Color(0xFF7BC393);
  static const Color objectiveInProgress = Color(0xFF7E6AD8);
  static const Color objectiveNotStarted = Color(0xFFBFC5D1);

  /// Couleurs pour la méditation
  static const Color meditationActive = Color(0xFF7E6AD8);
  static const Color meditationBreathing = Color(0xFFA99AF0);

  /// Gradient pour le chatbot
  static const LinearGradient chatbotGradient = LinearGradient(
    colors: [Color(0xFF7E6AD8), Color(0xFFA99AF0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Gradient pour les cartes importantes
  static const LinearGradient cardGradient = LinearGradient(
    colors: [
      Color(0xFFFAF8F5),
      Color(0xFFEBE3FF),
    ], // Beige clair -> Lavande glossy très pâle
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ==================== COULEURS SCAFFOLD ====================

  /// Toile de fond des pages, et teinte du bandeau de verre.
  static const Color scaffoldLight = backgroundLight;
  static const Color scaffoldDark = backgroundDark;

  // ==================== COULEURS GLASSMORPHISM ====================

  /// Glass backgrounds - jeton glass v2, translucide sur la scène.
  static const Color glassBackgroundLight = Color(0xBDFAF9FD); // 74 %
  static const Color glassBackgroundLightEnd = Color(0x99FFFFFF); // 60 %

  static const Color glassBackgroundDark = Color(0xA81C1928); // 66 %
  static const Color glassBackgroundDarkEnd = Color(0x0DFFFFFF); // 5 %

  /// Glass borders: jeton glass-stroke v2, filet clair qui accroche la lumière.
  static const Color glassBorderLight = Color(0xE6FFFFFF); // 90 %
  static const Color glassBorderDark = Color(0x1AFFFFFF); // 10 %

  /// Standard v2 sheet glass (`rgba(30,27,42,.9)` dark).
  static Color sheetGlass(bool dark) =>
      dark ? const Color(0xE61E1B2A) : glassBackgroundLight;

  /// Couleurs lavande pour effets spéciaux
  static const Color glassLavender = Color(0xFFF5F3FF);
  static const Color glassLavenderBorder = Color(0xFFE0D4FF);

  // ==================== COULEURS ICÔNES NAVIGATION ====================

  /// Icônes par défaut dans la navigation
  static const Color iconDefaultLight = Color(0xFF2B2640);
  static const Color iconDefaultDark = Color(0xFFE7E4F2);

  // ==================== COULEURS OVERLAY ====================

  /// Overlays pour les états interactifs
  static const Color overlay = Color(0x0A000000);
  static const Color overlayPressed = Color(0x14000000);
  static const Color overlayFocused = Color(0x1F000000);
  static const Color overlayHovered = Color(0x0A000000);

  /// Overlay pour les modals/dialogs
  static const Color scrim = Color(0x80000000);

  /// Preserve pastel hues in decoration while keeping text readable.
  static Color readableAccent(Color color, {required bool isDark}) {
    // surface-2 sombre est translucide : la luminance se mesure sur sa
    // composition réelle au-dessus du fond.
    final background = isDark
        ? Color.alphaBlend(cardDark, backgroundDark)
        : scaffoldLight;
    final luminance = background.computeLuminance();
    var hsl = HSLColor.fromColor(color.withValues(alpha: 1));
    if (!isDark) hsl = hsl.withSaturation(hsl.saturation.clamp(0.0, 0.5));
    for (var i = 0; i < 40; i++) {
      final foreground = hsl.toColor().computeLuminance();
      final ratio = foreground > luminance
          ? (foreground + 0.05) / (luminance + 0.05)
          : (luminance + 0.05) / (foreground + 0.05);
      if (ratio >= 7.0) return hsl.toColor();
      hsl = hsl.withLightness(
        (hsl.lightness + (isDark ? 0.025 : -0.025)).clamp(0.0, 1.0),
      );
    }
    return isDark ? textPrimaryDark : textPrimaryLight;
  }
}

/// Text colors for the current theme, so screens stop repeating the
/// light/dark choice.
extension AppTextColors on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  Color get textPrimary =>
      _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

  Color get textSecondary =>
      _isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

  Color get textTertiary =>
      _isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
}
