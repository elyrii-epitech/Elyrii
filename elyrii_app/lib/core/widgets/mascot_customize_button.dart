import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../../features/mascot/presentation/providers/mascot_provider.dart';

/// Bouton de personnalisation de la mascotte (effet liquid glass, subtil).
///
/// Affiche un point quand des cosmétiques sont équipés.
/// Concu pour etre place en overlay sur la page Home.
class MascotCustomizeButton extends StatefulWidget {
  final VoidCallback? onTap;
  final bool isDark;

  const MascotCustomizeButton({super.key, this.onTap, this.isDark = false});

  @override
  State<MascotCustomizeButton> createState() => _MascotCustomizeButtonState();
}

class _MascotCustomizeButtonState extends State<MascotCustomizeButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final equippedCount = context.select<MascotProvider, int>(
      (p) => p.mascot.equippedCosmetics.length,
    );
    final themeIsNotDefault = context.select<MascotProvider, bool>(
      (p) => p.mascot.themeId != 'nature',
    );
    final showBadge = equippedCount > 0 || themeIsNotDefault;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Stack(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: widget.isDark
                            ? [
                                Colors.white.withValues(alpha: 0.15),
                                Colors.white.withValues(alpha: 0.08),
                              ]
                            : [
                                const Color(0xFFFFFFFF).withValues(alpha: 0.85),
                                const Color(0xFFF8F8FB).withValues(alpha: 0.75),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: widget.isDark
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.08),
                        width: 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: widget.isDark ? 0.3 : 0.1,
                          ),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 21,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  if (showBadge)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.isDark
                                ? Colors.white.withValues(alpha: 0.4)
                                : Colors.white,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
