import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../services/glass_performance_service.dart';

/// Configuration prédéfinie pour les effets glass iOS 26 Liquid Glass
enum GlassIntensity {
  /// Flou ultra léger (sigma: 10) - ultraThin, très transparent
  ultraThin,

  /// Flou léger (sigma: 12) - pour les cartes de citation
  light,

  /// Flou standard (sigma: 16) - pour les stats et streaks
  medium,

  /// Flou prononcé (sigma: 22) - pour les cartes principales
  strong,

  /// Flou intense (sigma: 28) - iOS 26 standard pour navbar et boutons
  intense,

  /// Liquid Glass iOS 26 (sigma: 28) - avec highlight spéculaire
  liquidGlass,

  /// Clear variant - très transparent pour overlays sur images/vidéos
  clear,
}

/// Widget réutilisable pour l'effet glassmorphism iOS 26 Liquid Glass
/// Encapsule BackdropFilter + RepaintBoundary pour optimiser les performances GPU
/// Supporte le highlight spéculaire, le gradient adaptatif et la réduction de blur au scroll
///
/// Exemple d'utilisation:
/// ```dart
/// GlassContainer(
///   isDark: isDark,
///   borderRadius: AppDimensions.radiusLiquidGlassCard,
///   intensity: GlassIntensity.liquidGlass,
///   child: Text('Contenu'),
/// )
/// ```
class GlassContainer extends StatelessWidget {
  /// Contenu du container
  final Widget child;

  /// Mode sombre activé
  final bool isDark;

  /// Rayon des coins (défaut: AppDimensions.radiusLg pour iOS 26)
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

  /// Activer le highlight spéculaire iOS 26 (reflet en haut)
  final bool showSpecularHighlight;

  /// Couleur de teinte adaptative (pour gradient adaptatif au background)
  /// Si fournie, ajoute une légère teinte de cette couleur au glass
  final Color? adaptiveTintColor;

  /// Vitesse de scroll pour réduction adaptative du blur (0.0 à 1.0)
  /// Utilisé avec GlassPerformanceService.adaptiveBlurOnScroll
  final double scrollVelocity;

  const GlassContainer({
    super.key,
    required this.child,
    this.isDark = false,
    this.borderRadius = AppDimensions.radiusLg,
    this.intensity = GlassIntensity.medium,
    this.padding,
    this.gradientColors,
    this.borderColor,
    this.borderWidth = 1.0,
    this.boxShadow,
    this.disableRepaintBoundary = false,
    this.showSpecularHighlight = false,
    this.adaptiveTintColor,
    this.scrollVelocity = 0.0,
  });

  /// Retourne le sigma du flou selon l'intensité (iOS 26 values)
  double get _blurSigma {
    final performanceService = GlassPerformanceService();
    double baseSigma;

    switch (intensity) {
      case GlassIntensity.ultraThin:
        baseSigma = AppDimensions.blurSigmaLiquidGlassUltraThin; // 10.0
      case GlassIntensity.light:
        baseSigma = 12.0;
      case GlassIntensity.medium:
        baseSigma = AppDimensions.blurSigmaLiquidGlassThin; // 16.0
      case GlassIntensity.strong:
        baseSigma = AppDimensions.blurSigmaLiquidGlassRegular; // 22.0
      case GlassIntensity.intense:
      case GlassIntensity.liquidGlass:
        baseSigma = AppDimensions.blurSigmaLiquidGlass; // 28.0
      case GlassIntensity.clear:
        baseSigma = 5.0;
    }

    // Appliquer la réduction de blur si scroll velocity > 0
    if (scrollVelocity > 0) {
      return performanceService.getScrollAdaptedBlurSigma(
          baseSigma, scrollVelocity);
    }

    return performanceService.getEffectiveBlurSigma(baseSigma);
  }

  /// Couleurs de gradient par défaut (iOS 26 Liquid Glass)
  List<Color> get _defaultGradientColors {
    // Si clear variant, très transparent
    if (intensity == GlassIntensity.clear) {
      return isDark
          ? [
              Colors.white.withValues(alpha: 0.05),
              Colors.white.withValues(alpha: 0.02),
            ]
          : [
              Colors.black.withValues(alpha: 0.03),
              Colors.black.withValues(alpha: 0.01),
            ];
    }

    // iOS 26 Liquid Glass: opacités réduites pour plus de transparence
    if (intensity == GlassIntensity.liquidGlass ||
        intensity == GlassIntensity.intense) {
      if (isDark) {
        return [
          AppColors.liquidGlassBackgroundDark,
          AppColors.liquidGlassBackgroundDarkEnd,
        ];
      }
      return [
        AppColors.liquidGlassBackgroundLight,
        AppColors.liquidGlassBackgroundLightEnd,
      ];
    }

    // Valeurs par défaut pour les autres intensités
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

  /// Couleur de bordure par défaut (iOS 26)
  Color get _defaultBorderColor {
    if (intensity == GlassIntensity.liquidGlass ||
        intensity == GlassIntensity.intense) {
      return isDark
          ? AppColors.liquidGlassBorderDark
          : AppColors.liquidGlassBorderLight;
    }

    if (isDark) {
      return AppColors.glassBorderDark;
    }
    return AppColors.glassBorderLight;
  }

  /// Construit le highlight spéculaire iOS 26 (reflet en haut)
  Widget? _buildSpecularHighlight() {
    final performanceService = GlassPerformanceService();
    if (!showSpecularHighlight || !performanceService.showSpecularHighlight) {
      return null;
    }

    final isLiquidGlass = intensity == GlassIntensity.liquidGlass ||
        intensity == GlassIntensity.intense;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: borderRadius * 1.5,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(borderRadius),
            topRight: Radius.circular(borderRadius),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              isLiquidGlass
                  ? AppColors.liquidGlassSpecularStrong
                  : AppColors.liquidGlassSpecular,
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  /// Construit l'overlay de teinte adaptative
  Widget? _buildAdaptiveTintOverlay() {
    final performanceService = GlassPerformanceService();
    if (adaptiveTintColor == null || !performanceService.showAdaptiveGradient) {
      return null;
    }

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          color: adaptiveTintColor!.withValues(alpha: 0.05),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBlurSigma = _blurSigma;

    // Si blur désactivé, afficher un container simple
    if (effectiveBlurSigma <= 0) {
      return Container(
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
      );
    }

    final glassWidget = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: effectiveBlurSigma, sigmaY: effectiveBlurSigma),
        child: Stack(
          children: [
            // Container principal
            Container(
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
                boxShadow: boxShadow ??
                    [
                      // iOS 26: ombre douce par défaut
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
              ),
              child: child,
            ),
            // Highlight spéculaire iOS 26
            if (_buildSpecularHighlight() != null) _buildSpecularHighlight()!,
            // Overlay de teinte adaptative
            if (_buildAdaptiveTintOverlay() != null)
              _buildAdaptiveTintOverlay()!,
          ],
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
    double borderRadius = AppDimensions.radiusLg,
    GlassIntensity intensity = GlassIntensity.medium,
    EdgeInsetsGeometry? padding,
    bool showSpecularHighlight = false,
  }) {
    return GlassContainer(
      isDark: isDark,
      borderRadius: borderRadius,
      intensity: intensity,
      padding: padding,
      showSpecularHighlight: showSpecularHighlight,
      child: this,
    );
  }

  /// Enveloppe le widget dans un GlassContainer avec style iOS 26 Liquid Glass
  Widget liquidGlass({
    bool isDark = false,
    double borderRadius = AppDimensions.radiusLiquidGlassCard,
    EdgeInsetsGeometry? padding,
    Color? adaptiveTintColor,
  }) {
    return GlassContainer(
      isDark: isDark,
      borderRadius: borderRadius,
      intensity: GlassIntensity.liquidGlass,
      padding: padding,
      showSpecularHighlight: true,
      adaptiveTintColor: adaptiveTintColor,
      child: this,
    );
  }
}
