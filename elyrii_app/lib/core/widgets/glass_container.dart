import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// Configuration prédéfinie pour les effets glass
enum GlassIntensity {
  /// Flou léger (sigma: 8) - pour les cartes de citation
  light,

  /// Flou standard (sigma: 10) - pour les stats et streaks
  medium,

  /// Flou prononcé (sigma: 15) - pour les cartes principales
  strong,

  /// Flou intense (sigma: 20) - pour la navbar et boutons
  intense,
}

/// Widget réutilisable pour l'effet glassmorphism
/// Encapsule BackdropFilter + RepaintBoundary pour optimiser les performances GPU
///
/// Exemple d'utilisation:
/// ```dart
/// GlassContainer(
///   isDark: isDark,
///   borderRadius: AppDimensions.radiusMd,
///   child: Text('Contenu'),
/// )
/// ```
class GlassContainer extends StatelessWidget {
  /// Contenu du container
  final Widget child;

  /// Mode sombre activé
  final bool isDark;

  /// Rayon des coins (défaut: AppDimensions.radiusMd)
  final double borderRadius;

  /// Intensité de l'effet de flou
  final GlassIntensity intensity;

  /// Padding interne (optionnel)
  final EdgeInsetsGeometry? padding;

  /// Couleurs de gradient personnalisées (optionnel)
  /// Si null, utilise les couleurs par défaut selon isDark
  final List<Color>? gradientColors;

  /// Couleur de bordure personnalisée (optionnel)
  final Color? borderColor;

  /// Épaisseur de la bordure
  final double borderWidth;

  /// Box shadows personnalisées (optionnel)
  final List<BoxShadow>? boxShadow;

  /// Désactiver le RepaintBoundary (pour les widgets qui changent souvent)
  final bool disableRepaintBoundary;

  const GlassContainer({
    super.key,
    required this.child,
    this.isDark = false,
    this.borderRadius = AppDimensions.radiusMd,
    this.intensity = GlassIntensity.medium,
    this.padding,
    this.gradientColors,
    this.borderColor,
    this.borderWidth = 1.0,
    this.boxShadow,
    this.disableRepaintBoundary = false,
  });

  /// Retourne le sigma du flou selon l'intensité
  double get _blurSigma {
    switch (intensity) {
      case GlassIntensity.light:
        return 8.0;
      case GlassIntensity.medium:
        return 10.0;
      case GlassIntensity.strong:
        return 15.0;
      case GlassIntensity.intense:
        return 20.0;
    }
  }

  /// Couleurs de gradient par défaut
  List<Color> get _defaultGradientColors {
    if (isDark) {
      return [
        AppColors.glassBackgroundDark,
        AppColors.glassBackgroundDarkEnd,
      ];
    }
    return [
      AppColors.glassBackgroundLight,
      AppColors.glassBackgroundLightEnd,
    ];
  }

  /// Couleur de bordure par défaut
  Color get _defaultBorderColor {
    if (isDark) {
      return AppColors.glassBorderDark;
    }
    return AppColors.glassBorderLight;
  }

  @override
  Widget build(BuildContext context) {
    final glassWidget = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors ?? _defaultGradientColors,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? _defaultBorderColor,
              width: borderWidth,
            ),
            boxShadow: boxShadow,
          ),
          child: child,
        ),
      ),
    );

    // RepaintBoundary isole le coût GPU du BackdropFilter
    if (disableRepaintBoundary) {
      return glassWidget;
    }

    return RepaintBoundary(
      child: glassWidget,
    );
  }
}

/// Extension pour créer rapidement des containers glass
extension GlassContainerX on Widget {
  /// Enveloppe le widget dans un GlassContainer
  Widget glass({
    bool isDark = false,
    double borderRadius = AppDimensions.radiusMd,
    GlassIntensity intensity = GlassIntensity.medium,
    EdgeInsetsGeometry? padding,
  }) {
    return GlassContainer(
      isDark: isDark,
      borderRadius: borderRadius,
      intensity: intensity,
      padding: padding,
      child: this,
    );
  }
}
