import 'package:flutter/material.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../../core/glass/elyrii_glass_surface.dart';

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
    return Semantics(
      button: true,
      label: 'Paramètres',
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _isPressed = true);
          ElyriiHaptics.light();
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
          child: ElyriiGlassSurface(
            role: GlassRole.floatingControl,
            borderRadius: BorderRadius.circular(22),
            width: 44,
            height: 44,
            child: Stack(
              children: [
                Center(
                  child: RotationTransition(
                    turns: Tween(begin: 0.0, end: 0.25).animate(
                      CurvedAnimation(
                        parent: _rotateController,
                        curve: Curves.easeInOut,
                      ),
                    ),
                    child: Icon(
                      Icons.settings_rounded,
                      size: 22,
                      color: widget.isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _flashAnimation,
                  builder: (context, child) {
                    if (_flashAnimation.value <= 0) return const SizedBox();
                    return Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          color: Colors.white.withValues(
                            alpha: (0.3 * (1 - _flashAnimation.value)).clamp(
                              0.0,
                              1.0,
                            ),
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
    );
  }
}
