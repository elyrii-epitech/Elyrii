import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/dashboard_provider.dart';

/// Widget mascotte avec effet "peek" (dépasse du haut de l'écran)
class MascotPeek extends StatefulWidget {
  final MoodType? selectedMood;
  final VoidCallback? onTap;
  final bool isDark;

  const MascotPeek({
    super.key,
    this.selectedMood,
    this.onTap,
    this.isDark = false,
  });

  @override
  State<MascotPeek> createState() => _MascotPeekState();
}

class _MascotPeekState extends State<MascotPeek> with TickerProviderStateMixin {
  late AnimationController _floatController;
  late AnimationController _blinkController;
  late AnimationController _reactionController;
  late Animation<double> _floatAnimation;
  late Animation<double> _blinkAnimation;
  late Animation<double> _reactionAnimation;

  // ignore: unused_field
  bool _showEyesClosed = false;

  @override
  void initState() {
    super.initState();

    // Animation de flottement subtil
    _floatController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: 0, end: 6).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );

    // Animation de clignement
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.1).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    // Animation de réaction au mood
    _reactionController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _reactionAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _reactionController, curve: Curves.elasticOut),
    );

    // Clignement périodique
    _startBlinking();
  }

  void _startBlinking() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showEyesClosed = true);
        _blinkController.forward().then((_) {
          _blinkController.reverse().then((_) {
            if (mounted) {
              setState(() => _showEyesClosed = false);
              _startBlinking();
            }
          });
        });
      }
    });
  }

  @override
  void didUpdateWidget(MascotPeek oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Réaction quand le mood change
    if (widget.selectedMood != oldWidget.selectedMood &&
        widget.selectedMood != null) {
      _reactionController.forward().then((_) {
        _reactionController.reverse();
      });
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    _blinkController.dispose();
    _reactionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap?.call();

        // Petit rebond au tap
        _reactionController.forward().then((_) {
          _reactionController.reverse();
        });
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_floatAnimation, _reactionAnimation]),
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _floatAnimation.value),
            child: Transform.scale(
              scale: _reactionAnimation.value,
              child: child,
            ),
          );
        },
        child: Container(
          width: 120,
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary.withValues(alpha: 0.95),
                AppColors.primary.withValues(alpha: 0.85),
                AppColors.accent.withValues(alpha: 0.7),
              ],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(60),
              bottomRight: Radius.circular(60),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: 2,
              ),
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.2),
                blurRadius: 40,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Reflets décoratifs
              Positioned(
                top: 15,
                right: 25,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: 30,
                left: 20,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // Visage de la mascotte
              Positioned(bottom: 15, child: _buildFace()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFace() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Yeux
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildEye(isLeft: true),
            const SizedBox(width: 20),
            _buildEye(isLeft: false),
          ],
        ),
        const SizedBox(height: 8),
        // Bouche (réagit au mood)
        _buildMouth(),
      ],
    );
  }

  Widget _buildEye({required bool isLeft}) {
    return AnimatedBuilder(
      animation: _blinkAnimation,
      builder: (context, child) {
        return Container(
          width: 14,
          height: 14 * _blinkAnimation.value,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(7),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.5),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMouth() {
    // Adapter l'expression selon le mood
    if (widget.selectedMood == null) {
      // Expression neutre / sourire léger
      return Container(
        width: 20,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
        ),
      );
    }

    switch (widget.selectedMood!) {
      case MoodType.verySad:
      case MoodType.sad:
        // Bouche triste (incurvée vers le bas)
        return Transform.rotate(
          angle: 3.14159, // 180 degrés
          child: Container(
            width: 16,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
            ),
          ),
        );
      case MoodType.neutral:
        // Bouche neutre (ligne)
        return Container(
          width: 18,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      case MoodType.happy:
        // Sourire
        return Container(
          width: 22,
          height: 10,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
        );
      case MoodType.veryHappy:
        // Grand sourire avec "joues"
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Joue gauche
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 26,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Joue droite
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
          ],
        );
    }
  }
}
