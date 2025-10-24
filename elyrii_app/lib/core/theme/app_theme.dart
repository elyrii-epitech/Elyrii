import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_dimensions.dart';

/// Thème de l'application Elyrii
/// Contient les configurations complètes pour le mode clair et sombre
class AppTheme {
  AppTheme._();

  // ==================== LIGHT THEME ====================
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      
      // Couleurs principales
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        primaryContainer: AppColors.primaryLight,
        secondary: AppColors.secondary,
        secondaryContainer: AppColors.secondaryLight,
        tertiary: AppColors.accent,
        tertiaryContainer: AppColors.accentLight,
        error: AppColors.error,
        errorContainer: AppColors.errorLight,
        surface: AppColors.surfaceLight,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onTertiary: Colors.white,
        onError: Colors.white,
        onSurface: AppColors.textPrimaryLight,
        onSurfaceVariant: AppColors.textSecondaryLight,
        outline: AppColors.borderLight,
        shadow: AppColors.shadowLight,
      ),
      
      // AppBar
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.textPrimaryLight,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: AppTextStyles.titleLarge(
          color: AppColors.textPrimaryLight,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.textPrimaryLight,
          size: AppDimensions.iconMd,
        ),
      ),
      
      // Cards
      cardTheme: CardThemeData(
        elevation: AppDimensions.elevationSm,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        color: AppColors.cardLight,
        margin: const EdgeInsets.all(AppDimensions.spacingSm),
      ),
      
      // Boutons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: AppDimensions.elevationSm,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          textStyle: AppTextStyles.button(),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
          side: const BorderSide(
            color: AppColors.primary,
            width: AppDimensions.borderWidthMedium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          textStyle: AppTextStyles.button(),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTextStyles.button(),
        ),
      ),
      
      // Champs de texte
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingMd,
          vertical: AppDimensions.paddingMd,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(
            color: AppColors.borderLight,
            width: AppDimensions.borderWidthThin,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(
            color: AppColors.borderLight,
            width: AppDimensions.borderWidthThin,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: AppDimensions.borderWidthMedium,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: AppDimensions.borderWidthThin,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: AppDimensions.borderWidthMedium,
          ),
        ),
        hintStyle: AppTextStyles.inputHint(),
        labelStyle: AppTextStyles.bodyMedium(
          color: AppColors.textSecondaryLight,
        ),
        errorStyle: AppTextStyles.error(),
      ),
      
      // Bottom Navigation Bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textTertiaryLight,
        type: BottomNavigationBarType.fixed,
        elevation: AppDimensions.elevationMd,
        selectedIconTheme: IconThemeData(
          size: AppDimensions.iconMd,
        ),
        unselectedIconTheme: IconThemeData(
          size: AppDimensions.iconMd,
        ),
      ),
      
      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: AppDimensions.elevationLg,
      ),
      
      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLight,
        elevation: AppDimensions.elevationXl,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        ),
        titleTextStyle: AppTextStyles.titleLarge(
          color: AppColors.textPrimaryLight,
        ),
        contentTextStyle: AppTextStyles.bodyMedium(
          color: AppColors.textSecondaryLight,
        ),
      ),
      
      // SnackBars
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimaryLight,
        contentTextStyle: AppTextStyles.bodyMedium(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      
      // Dividers
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerLight,
        thickness: AppDimensions.dividerThickness,
        space: AppDimensions.spacingMd,
      ),
      
      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.cardLight,
        deleteIconColor: AppColors.textSecondaryLight,
        labelStyle: AppTextStyles.labelMedium(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingSm,
          vertical: AppDimensions.paddingXs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCircular),
        ),
      ),
      
      // Progress Indicators
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      
      // Icons
      iconTheme: const IconThemeData(
        color: AppColors.textPrimaryLight,
        size: AppDimensions.iconMd,
      ),
    );
  }

  // ==================== DARK THEME ====================
  
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      
      // Couleurs principales
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        primaryContainer: AppColors.primaryDark,
        secondary: AppColors.secondary,
        secondaryContainer: AppColors.secondaryDark,
        tertiary: AppColors.accent,
        tertiaryContainer: AppColors.accentDark,
        error: AppColors.error,
        errorContainer: AppColors.errorDark,
        surface: AppColors.surfaceDark,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onTertiary: Colors.white,
        onError: Colors.white,
        onSurface: AppColors.textPrimaryDark,
        onSurfaceVariant: AppColors.textSecondaryDark,
        outline: AppColors.borderDark,
        shadow: AppColors.shadowDark,
      ),
      
      // AppBar
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: AppColors.textPrimaryDark,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: AppTextStyles.titleLarge(
          color: AppColors.textPrimaryDark,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.textPrimaryDark,
          size: AppDimensions.iconMd,
        ),
      ),
      
      // Cards
      cardTheme: CardThemeData(
        elevation: AppDimensions.elevationSm,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        color: AppColors.cardDark,
        margin: const EdgeInsets.all(AppDimensions.spacingSm),
      ),
      
      // Boutons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: AppDimensions.elevationSm,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          textStyle: AppTextStyles.button(),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
          side: const BorderSide(
            color: AppColors.primary,
            width: AppDimensions.borderWidthMedium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          textStyle: AppTextStyles.button(),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTextStyles.button(),
        ),
      ),
      
      // Champs de texte
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingMd,
          vertical: AppDimensions.paddingMd,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(
            color: AppColors.borderDark,
            width: AppDimensions.borderWidthThin,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(
            color: AppColors.borderDark,
            width: AppDimensions.borderWidthThin,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: AppDimensions.borderWidthMedium,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: AppDimensions.borderWidthThin,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: AppDimensions.borderWidthMedium,
          ),
        ),
        hintStyle: AppTextStyles.inputHint().copyWith(
          color: AppColors.textTertiaryDark,
        ),
        labelStyle: AppTextStyles.bodyMedium(
          color: AppColors.textSecondaryDark,
        ),
        errorStyle: AppTextStyles.error(),
      ),
      
      // Bottom Navigation Bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textTertiaryDark,
        type: BottomNavigationBarType.fixed,
        elevation: AppDimensions.elevationMd,
        selectedIconTheme: IconThemeData(
          size: AppDimensions.iconMd,
        ),
        unselectedIconTheme: IconThemeData(
          size: AppDimensions.iconMd,
        ),
      ),
      
      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: AppDimensions.elevationLg,
      ),
      
      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDark,
        elevation: AppDimensions.elevationXl,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        ),
        titleTextStyle: AppTextStyles.titleLarge(
          color: AppColors.textPrimaryDark,
        ),
        contentTextStyle: AppTextStyles.bodyMedium(
          color: AppColors.textSecondaryDark,
        ),
      ),
      
      // SnackBars
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        contentTextStyle: AppTextStyles.bodyMedium(
          color: AppColors.textPrimaryDark,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      
      // Dividers
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerDark,
        thickness: AppDimensions.dividerThickness,
        space: AppDimensions.spacingMd,
      ),
      
      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.cardDark,
        deleteIconColor: AppColors.textSecondaryDark,
        labelStyle: AppTextStyles.labelMedium(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingSm,
          vertical: AppDimensions.paddingXs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCircular),
        ),
      ),
      
      // Progress Indicators
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      
      // Icons
      iconTheme: const IconThemeData(
        color: AppColors.textPrimaryDark,
        size: AppDimensions.iconMd,
      ),
    );
  }
}
