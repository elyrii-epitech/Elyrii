import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Styles de texte de l'application Elyrii
/// Définit tous les styles typographiques pour maintenir la cohérence
class AppTextStyles {
  AppTextStyles._(); // Constructeur privé

  // Police de base - Utilise la police système par défaut
  // Vous pouvez personnaliser avec Google Fonts en ajoutant le package plus tard
  static const String _fontFamily = 'Poppins'; // À remplacer par la police de votre choix
  
  // ==================== DISPLAY STYLES ====================
  // Utilisés pour les titres très larges (splash, onboarding)
  
  static TextStyle displayLarge({Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 57,
      fontWeight: fontWeight ?? FontWeight.w700,
      color: color,
      height: 1.12,
      letterSpacing: -0.25,
    );
  }

  static TextStyle displayMedium({Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 45,
      fontWeight: fontWeight ?? FontWeight.w700,
      color: color,
      height: 1.16,
      letterSpacing: 0,
    );
  }

  static TextStyle displaySmall({Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 36,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color,
      height: 1.22,
      letterSpacing: 0,
    );
  }

  // ==================== HEADLINE STYLES ====================
  // Utilisés pour les titres de sections importantes
  
  static TextStyle headlineLarge({Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 32,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color,
      height: 1.25,
      letterSpacing: 0,
    );
  }

  static TextStyle headlineMedium({Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 28,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color,
      height: 1.29,
      letterSpacing: 0,
    );
  }

  static TextStyle headlineSmall({Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 24,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color,
      height: 1.33,
      letterSpacing: 0,
    );
  }

  // ==================== TITLE STYLES ====================
  // Utilisés pour les titres de cartes, dialogs, etc.
  
  static TextStyle titleLarge({Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 22,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color,
      height: 1.27,
      letterSpacing: 0,
    );
  }

  static TextStyle titleMedium({Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 16,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color,
      height: 1.5,
      letterSpacing: 0.15,
    );
  }

  static TextStyle titleSmall({Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 14,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color,
      height: 1.43,
      letterSpacing: 0.1,
    );
  }

  // ==================== BODY STYLES ====================
  // Utilisés pour le texte principal
  
  static TextStyle bodyLarge({Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 16,
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color,
      height: 1.5,
      letterSpacing: 0.5,
    );
  }

  static TextStyle bodyMedium({Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 14,
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color,
      height: 1.43,
      letterSpacing: 0.25,
    );
  }

  static TextStyle bodySmall({Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 12,
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color,
      height: 1.33,
      letterSpacing: 0.4,
    );
  }

  // ==================== LABEL STYLES ====================
  // Utilisés pour les boutons, chips, labels
  
  static TextStyle labelLarge({Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 14,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color,
      height: 1.43,
      letterSpacing: 0.1,
    );
  }

  static TextStyle labelMedium({Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 12,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color,
      height: 1.33,
      letterSpacing: 0.5,
    );
  }

  static TextStyle labelSmall({Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 11,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color,
      height: 1.45,
      letterSpacing: 0.5,
    );
  }

  // ==================== STYLES SPÉCIFIQUES ====================
  
  /// Style pour les messages du chatbot
  static TextStyle chatbotMessage({bool isUser = false}) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: isUser ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      height: 1.5,
      letterSpacing: 0.3,
    );
  }

  /// Style pour le contenu du journal intime
  static TextStyle journalEntry() {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimaryLight,
      height: 1.6,
      letterSpacing: 0.3,
    );
  }

  /// Style pour les timestamps
  static TextStyle timestamp() {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.textTertiaryLight,
      height: 1.33,
      letterSpacing: 0.4,
    );
  }

  /// Style pour les étiquettes d'émotions
  static TextStyle emotionLabel() {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondaryLight,
      height: 1.38,
      letterSpacing: 0.3,
    );
  }

  /// Style pour les titres d'objectifs
  static TextStyle objectiveTitle() {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimaryLight,
      height: 1.5,
      letterSpacing: 0.15,
    );
  }

  /// Style pour les badges/achievements
  static TextStyle achievementBadge() {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Colors.white,
      height: 1.45,
      letterSpacing: 0.8,
    );
  }

  /// Style pour les statistiques numériques
  static TextStyle statNumber() {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: AppColors.primary,
      height: 1.25,
      letterSpacing: -0.5,
    );
  }

  /// Style pour les labels de statistiques
  static TextStyle statLabel() {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondaryLight,
      height: 1.38,
      letterSpacing: 0.3,
    );
  }

  /// Style pour les boutons principaux
  static TextStyle button() {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.33,
      letterSpacing: 0.5,
    );
  }

  /// Style pour les hints dans les champs de texte
  static TextStyle inputHint() {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.textTertiaryLight,
      height: 1.5,
      letterSpacing: 0.5,
    );
  }

  /// Style pour le texte des inputs
  static TextStyle inputText() {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimaryLight,
      height: 1.5,
      letterSpacing: 0.5,
    );
  }

  /// Style pour les erreurs
  static TextStyle error() {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.error,
      height: 1.33,
      letterSpacing: 0.4,
    );
  }

  /// Style pour les liens
  static TextStyle link() {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.primary,
      height: 1.43,
      letterSpacing: 0.25,
      decoration: TextDecoration.underline,
    );
  }

  // ==================== HELPERS ====================
  
  /// Applique une couleur à un style existant
  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }

  /// Applique un poids de police à un style existant
  static TextStyle withWeight(TextStyle style, FontWeight weight) {
    return style.copyWith(fontWeight: weight);
  }

  /// Applique une opacité à un style existant
  static TextStyle withOpacity(TextStyle style, double opacity) {
    return style.copyWith(color: style.color?.withOpacity(opacity));
  }
}
