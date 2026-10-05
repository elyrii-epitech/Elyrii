import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Palette sémantique unifiée Elyrii.
/// Inspirée des principes de clarté Apple : rôles fonctionnels plutôt que noms d'apparence.
abstract final class ElyriiColors {
  // Teintes fondamentales (Lavande apaisante, Pêche chaleureuse, Menthe douce)
  static const Color brandPrimary = AppColors.primary;
  static const Color brandSecondary = Color(0xFFFFB5A8);
  static const Color brandAccent = Color(0xFFA8D5BA);

  // Arrière-plans Scaffolds
  static const Color backgroundLight =
      AppColors.backgroundLight; // Écru chaud reposant
  static const Color backgroundDark =
      AppColors.backgroundDark; // Noir chocolat profond

  // Surfaces de contenu (Cartes, Conteneurs)
  static const Color surfaceLight = AppColors.surfaceLight;
  static const Color surfaceDark = AppColors.surfaceDark;

  // Verre Translucide (Liquid Glass fonctionnel)
  static const Color glassLight = Color(0xD9FFFFFF); // 85% blanc pur
  static const Color glassDark = Color(0x33FFFFFF); // 20% blanc sur fond noir
  static const Color glassBorderLight = Color(
    0x4DFFFFFF,
  ); // Bordure subtile 30%
  static const Color glassBorderDark = Color(0x26FFFFFF); // Bordure subtile 15%

  // Typographie & Contrastes
  static const Color textPrimaryLight = AppColors.textPrimaryLight;
  static const Color textPrimaryDark = AppColors.textPrimaryDark;
  static const Color textSecondaryLight = AppColors.textSecondaryLight;
  static const Color textSecondaryDark = AppColors.textSecondaryDark;
  static const Color textTertiaryLight = AppColors.textTertiaryLight;
  static const Color textTertiaryDark = AppColors.textTertiaryDark;

  // États sémantiques
  static const Color positive = Color(0xFF4E9A68);
  static const Color warning = Color(0xFFD97706);
  static const Color critical = Color(0xFFDC2626);
}
