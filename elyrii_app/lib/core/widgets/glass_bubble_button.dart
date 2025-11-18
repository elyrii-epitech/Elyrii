import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';

/// Bouton en forme de bulle avec effet liquid glass
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

  /// Calcule l'opacité du flash avec fade out progressif
  double _calculateFlashOpacity(double progress) {
    // Fade out progressif à partir de 70% de l'animation
    final fadeOut =
        progress > 0.7 ? (1.0 - ((progress - 0.7) / 0.3)).clamp(0.0, 1.0) : 1.0;

    return (0.3 * (1 - progress * 0.5) * fadeOut).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    // Couleur adaptée au thème : violet si sélectionné, #E6E5E2 en dark, #3A3A3D en light
    final effectiveIconColor = iconColor ??
        (isSelected
            ? AppColors.primary
            : (isDark ? const Color(0xFFE6E5E2) : const Color(0xFF3A3A3D)));
    final effectiveShimmerColor =
        shimmerColor ?? AppColors.primary.withValues(alpha: 0.3);

    Widget buttonContent = Container(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Flash blanc avec fade out progressif (comme la navbar)
          if (flashAnimation != null && flashAnimation!.value > 0)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(size / 2),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size / 2),
                    color: Colors.white.withValues(
                      alpha: _calculateFlashOpacity(flashAnimation!.value),
                    ),
                  ),
                ),
              ),
            ),
          // Bulle glass
          ClipRRect(
            borderRadius: BorderRadius.circular(size / 2),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  // Gradient de base plus contrasté en mode light
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            Colors.white.withValues(alpha: 0.12),
                            Colors.white.withValues(alpha: 0.08),
                          ]
                        : [
                            const Color(0xFFFFFFFF).withValues(alpha: 0.85),
                            const Color(0xFFF5F3FF).withValues(alpha: 0.75),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(size / 2),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : const Color(0xFFE0D4FF).withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                      blurRadius: 24,
                      spreadRadius: 0,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Container(
                  // Fond gris plus visible si sélectionné (comme la navbar)
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.12))
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
                            .animate(
                                onPlay: (controller) => controller.repeat())
                            .shimmer(
                              duration: 2000.ms,
                              delay: 3000.ms,
                              color: effectiveShimmerColor,
                            )
                        : Icon(
                            icon,
                            color: effectiveIconColor,
                            size: size * 0.4375,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // Appliquer le scale si l'animation est fournie
    if (scaleAnimation != null) {
      buttonContent = Transform.scale(
        scale: scaleAnimation!.value,
        child: buttonContent,
      );
    }

    // Appliquer l'effet de pression
    buttonContent = AnimatedScale(
      scale: isPressed ? 0.9 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeInOut,
      child: buttonContent,
    );

    // Wrapper avec tooltip si fourni
    if (tooltip != null) {
      buttonContent = Tooltip(
        message: tooltip!,
        child: buttonContent,
      );
    }

    return buttonContent;
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
