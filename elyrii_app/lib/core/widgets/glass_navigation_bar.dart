import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../services/glass_performance_service.dart';

/// Item de navigation pour la GlassNavigationBar
class GlassNavItem {
  final IconData icon;
  final String label;
  final int index;

  const GlassNavItem({
    required this.icon,
    required this.label,
    required this.index,
  });
}

/// Barre de navigation avec effet iOS 26 Liquid Glass
/// Widget réutilisable pour créer des navbars modernes
class GlassNavigationBar extends StatelessWidget {
  final List<GlassNavItem> items;
  final int currentIndex;
  final Function(int) onItemSelected;
  final List<AnimationController> iconControllers;
  final Animation<double>? scaleAnimation;
  final Animation<double>? flashAnimation;
  final bool isDark;
  final int pressedIndex;
  final EdgeInsets margin;
  final double height;
  final double borderRadius;

  const GlassNavigationBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onItemSelected,
    required this.iconControllers,
    this.scaleAnimation,
    this.flashAnimation,
    this.isDark = false,
    this.pressedIndex = -1,
    this.margin = const EdgeInsets.only(left: 16, right: 16, bottom: 24),
    this.height = 72.0,
    this.borderRadius = AppDimensions.radiusLiquidGlassNav, // iOS 26: 44.0
  });

  @override
  Widget build(BuildContext context) {
    final performanceService = GlassPerformanceService();
    final effectiveBlurSigma = performanceService.getEffectiveBlurSigma(
      AppDimensions.blurSigmaLiquidGlass,
    );

    return Container(
      margin: margin,
      height: height,
      child: Stack(
        children: [
          // Navbar glass iOS 26 Liquid Glass
          RepaintBoundary(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: effectiveBlurSigma > 0
                  ? BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: effectiveBlurSigma,
                        sigmaY: effectiveBlurSigma,
                      ),
                      child: _buildNavBarContainer(),
                    )
                  : _buildNavBarContainer(),
            ),
          ),
          // Highlight spéculaire iOS 26 (reflet en haut) - IgnorePointer pour ne pas bloquer les clics
          if (performanceService.showSpecularHighlight)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: borderRadius * 0.8,
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(borderRadius),
                    topRight: Radius.circular(borderRadius),
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.liquidGlassSpecularStrong,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Flash radial par-dessus
          if (flashAnimation != null && flashAnimation!.value > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Calculer la position X de l'item sélectionné
                      final itemWidth = constraints.maxWidth / items.length;
                      final selectedX = (currentIndex + 0.5) * itemWidth;
                      final centerY = constraints.maxHeight / 2;

                      return CustomPaint(
                        painter: RadialFlashPainter(
                          progress: flashAnimation!.value,
                          centerX: selectedX,
                          centerY: centerY,
                          maxRadius: constraints.maxWidth,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Construit le container principal de la navbar
  Widget _buildNavBarContainer() {
    return Container(
      decoration: BoxDecoration(
        // iOS 26: Gradient vertical pour plus de profondeur
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  AppColors.liquidGlassBackgroundDark,
                  AppColors.liquidGlassBackgroundDarkEnd,
                ]
              : [
                  AppColors.liquidGlassBackgroundLight,
                  AppColors.liquidGlassBackgroundLightEnd,
                ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDark
              ? AppColors.liquidGlassBorderDark
              : AppColors.liquidGlassBorderLight,
          width: 0.5, // iOS 26: bordure plus fine
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: items.map((item) {
          return _buildNavItem(
            item: item,
            controller: iconControllers[item.index],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNavItem({
    required GlassNavItem item,
    required AnimationController controller,
  }) {
    final isSelected = currentIndex == item.index;
    final isPressedItem = pressedIndex == item.index;
    const primaryColor = AppColors.primary;

    return Expanded(
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
        },
        onTapUp: (_) {
          onItemSelected(item.index);
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            // iOS 26: Animation spring avec damping 0.7
            final springValue = Curves.elasticOut.transform(controller.value);
            final scale = 1.0 + (springValue * 0.15); // Réduit de 0.2 à 0.15

            return AnimatedScale(
              scale: isPressedItem ? 0.95 : 1.0, // iOS 26: 0.95 au lieu de 0.9
              duration: const Duration(milliseconds: 100),
              child: AnimatedContainer(
                duration: const Duration(
                  milliseconds: AppDimensions.animationDurationLiquidGlass,
                ),
                curve: Curves.easeOutCubic, // iOS 26: easeOutCubic
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                decoration: BoxDecoration(
                  // Fond gris plus visible quand sélectionné
                  color: isSelected
                      ? (isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animation de translation (mouvement vers le haut)
                    Transform.translate(
                      offset: Offset(0, isSelected ? -2 * controller.value : 0),
                      child: Transform.scale(
                        scale: isSelected ? scale : 1.0,
                        child: Icon(
                          item.icon,
                          // Icône en violet si sélectionné, sinon couleur adaptée au thème
                          color: isSelected
                              ? primaryColor
                              : (isDark
                                  ? AppColors.iconDefaultDark
                                  : AppColors.iconDefaultLight),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Texte avec animation fade
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: 1.0,
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: isSelected ? 9.5 : 9,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          // Texte en violet si sélectionné, sinon couleur adaptée au thème
                          color: isSelected
                              ? primaryColor
                              : (isDark
                                  ? AppColors.iconDefaultDark
                                  : AppColors.iconDefaultLight),
                          letterSpacing: isSelected ? 0.3 : 0,
                        ),
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Painter pour créer un effet de flash radial iOS 26
class RadialFlashPainter extends CustomPainter {
  final double progress;
  final double centerX;
  final double centerY;
  final double maxRadius;

  RadialFlashPainter({
    required this.progress,
    required this.centerX,
    required this.centerY,
    required this.maxRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = Offset(centerX, centerY);
    final radius = maxRadius * 1.5 * progress; // Rayon plus grand

    // iOS 26: Fade out plus rapide à partir de 60% de l'animation
    final fadeOut = progress > 0.6
        ? (1.0 - ((progress - 0.6) / 0.4)).clamp(
            0.0,
            1.0,
          ) // De 1.0 à 0 entre 60% et 100%
        : 1.0;

    // Créer un gradient radial avec opacité qui diminue progressivement
    final gradient = RadialGradient(
      colors: [
        Colors.white.withValues(
          alpha: ((0.5 * (1 - progress * 0.5) * fadeOut).clamp(0.0, 1.0)),
        ),
        Colors.white.withValues(
          alpha: ((0.3 * (1 - progress * 0.6) * fadeOut).clamp(0.0, 1.0)),
        ),
        Colors.white.withValues(
          alpha: ((0.15 * (1 - progress * 0.8) * fadeOut).clamp(0.0, 1.0)),
        ),
        Colors.white.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(RadialFlashPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.centerX != centerX ||
        oldDelegate.centerY != centerY;
  }
}
