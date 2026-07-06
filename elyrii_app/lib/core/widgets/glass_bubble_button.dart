import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../services/glass_performance_service.dart';

/// Bouton en forme de bulle avec effet iOS 26 Liquid Glass
/// Peut être réutilisé pour chatbot, settings, notifications, etc.
class GlassBubbleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final double size;
  final bool showShimmer;
  final Color? shimmerColor;
  final bool isDark;
  final Animation<double>? scaleAnimation;
  final Animation<double>? flashAnimation;
  final bool isPressed;
  final String? tooltip;
  final bool isSelected;

  const GlassBubbleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.size = 64.0,
    this.showShimmer = false,
    this.shimmerColor,
    this.isDark = false,
    this.scaleAnimation,
    this.flashAnimation,
    this.isPressed = false,
    this.tooltip,
    this.isSelected = false,
  });

  /// Calcule l'opacité du flash avec fade out progressif iOS 26
  double _calculateFlashOpacity(double progress) {
    // iOS 26: Fade out plus rapide à partir de 60% de l'animation
    final fadeOut = progress > 0.6
        ? (1.0 - ((progress - 0.6) / 0.4)).clamp(0.0, 1.0)
        : 1.0;

    return (0.25 * (1 - progress * 0.5) * fadeOut).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final performanceService = GlassPerformanceService();
    final effectiveBlurSigma = performanceService.getEffectiveBlurSigma(
      AppDimensions.blurSigmaLiquidGlass,
    );

    // Couleur adaptée au thème : violet si sélectionné, sinon couleur par défaut
    final effectiveIconColor =
        iconColor ??
        (isSelected
            ? AppColors.primary
            : (isDark
                  ? AppColors.iconDefaultDark
                  : AppColors.iconDefaultLight));
    final effectiveShimmerColor =
        shimmerColor ?? AppColors.primary.withValues(alpha: 0.3);

    // Bulle glass iOS 26 - Avec BackdropFilter blur comme la navbar
    Widget buttonContent = RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: effectiveBlurSigma > 0
            ? BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: effectiveBlurSigma,
                  sigmaY: effectiveBlurSigma,
                ),
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    children: [
                      _buildButtonContent(
                        effectiveIconColor,
                        effectiveShimmerColor,
                        performanceService: performanceService,
                      ),
                      // Flash blanc avec fade out progressif iOS 26
                      if (flashAnimation != null && flashAnimation!.value > 0)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(size / 2),
                              color: Colors.white.withValues(
                                alpha: _calculateFlashOpacity(
                                  flashAnimation!.value,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              )
            : SizedBox(
                width: size,
                height: size,
                child: Stack(
                  children: [
                    _buildButtonContent(
                      effectiveIconColor,
                      effectiveShimmerColor,
                      performanceService: performanceService,
                    ),
                    // Flash blanc avec fade out progressif iOS 26
                    if (flashAnimation != null && flashAnimation!.value > 0)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(size / 2),
                            color: Colors.white.withValues(
                              alpha: _calculateFlashOpacity(
                                flashAnimation!.value,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );

    // Appliquer le scale si l'animation est fournie
    if (scaleAnimation != null) {
      buttonContent = Transform.scale(
        scale: scaleAnimation!.value,
        child: buttonContent,
      );
    }

    // iOS 26: scale 0.95 au lieu de 0.9
    buttonContent = AnimatedScale(
      scale: isPressed ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeInOut,
      child: buttonContent,
    );

    // Wrapper avec tooltip si fourni
    if (tooltip != null) {
      buttonContent = Tooltip(message: tooltip!, child: buttonContent);
    }

    return buttonContent;
  }

  Widget _buildButtonContent(
    Color effectiveIconColor,
    Color effectiveShimmerColor, {
    required GlassPerformanceService performanceService,
  }) {
    return Stack(
      children: [
        // Container principal - avec BackdropFilter blur
        Container(
          decoration: BoxDecoration(
            // iOS 26: Gradient vertical
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      Colors.white.withValues(alpha: 0.15),
                      Colors.white.withValues(alpha: 0.08),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.85),
                      Colors.white.withValues(alpha: 0.75),
                    ],
            ),
            borderRadius: BorderRadius.circular(size / 2),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.08),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                blurRadius: 16,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Container(
            // Fond plus visible si sélectionné
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.08))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(size / 2),
            ),
            child: Center(
              child: showShimmer
                  ? Icon(
                          icon,
                          color: effectiveIconColor,
                          size: size * 0.4375, // 28/64 ratio
                        )
                        .animate(onPlay: (controller) => controller.repeat())
                        .shimmer(
                          duration: 2000.ms,
                          delay: 3000.ms,
                          color: effectiveShimmerColor,
                        )
                  : Icon(icon, color: effectiveIconColor, size: size * 0.4375),
            ),
          ),
        ),
        // Highlight spéculaire iOS 26
        if (performanceService.showSpecularHighlight)
          Positioned(
            top: 0,
            left: size * 0.15,
            right: size * 0.15,
            height: size * 0.3,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(size / 2),
                  topRight: Radius.circular(size / 2),
                ),
                gradient: const LinearGradient(
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
      ],
    );
  }
}

/// Widget stateful qui gère l'état de pression pour GlassBubbleButton
class GlassBubbleButtonStateful extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final double size;
  final bool showShimmer;
  final Color? shimmerColor;
  final bool isDark;
  final Animation<double>? scaleAnimation;
  final Animation<double>? flashAnimation;
  final String? tooltip;
  final HapticFeedback? hapticFeedback;
  final bool isSelected;

  const GlassBubbleButtonStateful({
    super.key,
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.size = 64.0,
    this.showShimmer = false,
    this.shimmerColor,
    this.isDark = false,
    this.scaleAnimation,
    this.flashAnimation,
    this.tooltip,
    this.hapticFeedback,
    this.isSelected = false,
  });

  @override
  State<GlassBubbleButtonStateful> createState() =>
      _GlassBubbleButtonStatefulState();
}

class _GlassBubbleButtonStatefulState extends State<GlassBubbleButtonStateful> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticFeedback.mediumImpact();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: GlassBubbleButton(
        icon: widget.icon,
        onTap: widget.onTap,
        iconColor: widget.iconColor,
        size: widget.size,
        showShimmer: widget.showShimmer,
        shimmerColor: widget.shimmerColor,
        isDark: widget.isDark,
        scaleAnimation: widget.scaleAnimation,
        flashAnimation: widget.flashAnimation,
        isPressed: _isPressed,
        tooltip: widget.tooltip,
        isSelected: widget.isSelected,
      ),
    );
  }
}
