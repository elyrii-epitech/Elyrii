import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:iconsax/iconsax.dart';

/// Bouton settings avec effet liquid glass comme la navbar
class GlassSettingsButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isDark;

  const GlassSettingsButton({
    super.key,
    required this.onTap,
    this.isDark = false,
  });

  @override
  State<GlassSettingsButton> createState() => _GlassSettingsButtonState();
}

class _GlassSettingsButtonState extends State<GlassSettingsButton>
    with TickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _rotateController;
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _flashController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _flashAnimation = CurvedAnimation(
      parent: _flashController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticFeedback.lightImpact();
        _rotateController.forward();
        _flashController.forward(from: 0);
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _rotateController.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _rotateController.reverse();
      },
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
                  // Container principal avec BackdropFilter blur
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
                          color: Colors.black
                              .withValues(alpha: widget.isDark ? 0.3 : 0.1),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: RotationTransition(
                        turns: Tween(begin: 0.0, end: 0.25).animate(
                          CurvedAnimation(
                            parent: _rotateController,
                            curve: Curves.easeInOut,
                          ),
                        ),
                        child: Icon(
                          Iconsax.setting_2,
                          size: 22,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Flash radial overlay
                  AnimatedBuilder(
                    animation: _flashAnimation,
                    builder: (context, child) {
                      if (_flashAnimation.value <= 0) return const SizedBox();
                      return Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            color: Colors.white.withValues(
                              alpha: (0.3 * (1 - _flashAnimation.value)).clamp(0.0, 1.0),
                            ),
                          ),
                        ),
                      );
                    },
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


