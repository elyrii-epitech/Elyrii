import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../theme/app_colors.dart';

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

/// Barre de navigation avec effet liquid glass
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
    this.borderRadius = 36.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      height: height,
      child: Stack(
        children: [
          // Navbar glass (plus transparente)
          ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
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
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : const Color(0xFFE0D4FF).withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                      blurRadius: 24,
                      spreadRadius: 0,
                      offset: const Offset(0, 10),
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

  Widget _buildNavItem({
    required GlassNavItem item,
    required AnimationController controller,
  }) {
    final isSelected = currentIndex == item.index;
    final isPressedItem = pressedIndex == item.index;
    final primaryColor = AppColors.primary;

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
            // Animation de rebond pour l'icône
            final bounce = Curves.elasticOut.transform(controller.value);
            final scale = 1.0 + (bounce * 0.2);

            return AnimatedScale(
              scale: isPressedItem ? 0.95 : 1.0,
              duration: const Duration(milliseconds: 100),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                decoration: BoxDecoration(
                  // Fond gris plus visible quand sélectionné
                  color: isSelected
                      ? (isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.12))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
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
                                  ? const Color(0xFFE6E5E2)
                                  : const Color(0xFF3A3A3D)),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Texte
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
                                  ? const Color(0xFFE6E5E2)
                                  : const Color(0xFF3A3A3D)),
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

/// Painter pour créer un effet de flash radial
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

    // Fade out progressif à partir de 70% de l'animation
    final fadeOut = progress > 0.7
        ? (1.0 - ((progress - 0.7) / 0.3))
            .clamp(0.0, 1.0) // De 1.0 à 0 entre 70% et 100%
        : 1.0;

    // Créer un gradient radial avec opacité qui diminue progressivement
    final gradient = RadialGradient(
      colors: [
        Colors.white.withValues(
            alpha: ((0.6 * (1 - progress * 0.5) * fadeOut).clamp(0.0, 1.0))),
        Colors.white.withValues(
            alpha: ((0.4 * (1 - progress * 0.6) * fadeOut).clamp(0.0, 1.0))),
        Colors.white.withValues(
            alpha: ((0.2 * (1 - progress * 0.8) * fadeOut).clamp(0.0, 1.0))),
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
