import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/config/mascot_themes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/mascot_with_accessories.dart';
import '../../../mascot/presentation/providers/mascot_provider.dart';
import '../providers/dashboard_provider.dart';

/// Widget mascotte avec effet "peek" (dépasse du haut de l'écran).
///
/// Affiche le modèle 3D Elyrii dans un halo circulaire doux, avec
/// animation de flottement subtil et réaction au tap et au mood.
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
  late AnimationController _reactionController;
  late Animation<double> _floatAnimation;
  late Animation<double> _reactionAnimation;

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

    // Animation de réaction au tap / au mood
    _reactionController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _reactionAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _reactionController, curve: Curves.elasticOut),
    );
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
    _reactionController.dispose();
    super.dispose();
  }

  void _triggerReaction() {
    _reactionController.forward().then((_) {
      _reactionController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap?.call();
        _triggerReaction();
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
        child: _buildMascotHalo(),
      ),
    );
  }

  /// Halo circulaire doux contenant la mascotte 3D.
  Widget _buildMascotHalo() {
    final theme = context.select<MascotProvider, MascotTheme>(
      (p) => p.currentTheme,
    );
    final haloColor = theme.accentColor;

    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            haloColor.withValues(alpha: 0.22),
            haloColor.withValues(alpha: 0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.55),
              border: Border.all(
                color: Colors.white.withValues(
                  alpha: widget.isDark ? 0.16 : 0.7,
                ),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const MascotWithAccessories(
            config: Mascot3DConfig(
              autoRotate: false,
              interactionEnabled: false,
              showLoadingIndicator: false,
            ),
            width: 118,
            height: 118,
          ),
        ],
      ),
    );
  }
}
