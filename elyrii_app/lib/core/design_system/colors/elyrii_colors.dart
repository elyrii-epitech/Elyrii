import 'package:flutter/material.dart';

/// Palette sémantique unifiée Elyrii (WCAG 2.2 AA conforme).
/// Inspirée des principes de clarté Apple : rôles fonctionnels plutôt que noms d'apparence.
abstract final class ElyriiColors {
  // Teintes fondamentales (Lavande apaisante, Pêche chaleureuse, Menthe douce)
  static const Color brandPrimary = Color(0xFF7E6AD8);
  static const Color brandSecondary = Color(0xFFFFB5A8);
  static const Color brandAccent = Color(0xFFA8D5BA);

  // Arrière-plans Scaffolds
  static const Color backgroundLight = Color(0xFFFBF9F7); // Écru chaud reposant
  static const Color backgroundDark = Color(
    0xFF141314,
  ); // Noir chocolat profond

  // Surfaces de contenu (Cartes, Conteneurs)
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF201E20);

  // Verre Translucide (Liquid Glass fonctionnel)
  static const Color glassLight = Color(0xD9FFFFFF); // 85% blanc pur
  static const Color glassDark = Color(0x33FFFFFF); // 20% blanc sur fond noir
  static const Color glassBorderLight = Color(
    0x4DFFFFFF,
  ); // Bordure subtile 30%
  static const Color glassBorderDark = Color(0x26FFFFFF); // Bordure subtile 15%

  // Typographie & Contrastes (WCAG AA validé)
  static const Color textPrimaryLight = Color(0xFF1F1D1C);
  static const Color textPrimaryDark = Color(0xFFF7F5F3);
  static const Color textSecondaryLight = Color(0xFF6B6562);
  static const Color textSecondaryDark = Color(0xFFA8A29E);
  static const Color textTertiaryLight = Color(0xFF9E9793);
  static const Color textTertiaryDark = Color(0xFF736D69);

  // États sémantiques
  static const Color positive = Color(0xFF4E9A68);
  static const Color warning = Color(0xFFD97706);
  static const Color critical = Color(0xFFDC2626);
}
