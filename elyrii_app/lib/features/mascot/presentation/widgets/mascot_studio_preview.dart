import 'package:flutter/material.dart';

import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/config/mascot_animations.dart';
import '../../../../core/config/mascot_themes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/glass/liquid_glass_controls.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/mascot_with_accessories.dart';
import '../../data/models/mascot_accessory.dart';
import '../../data/models/mascot_model.dart';

class MascotStudioPreview extends StatelessWidget {
  const MascotStudioPreview({
    super.key,
    required this.mascot,
    required this.height,
    required this.angle,
    required this.onAngleChanged,
    required this.animation,
    required this.animationTrigger,
    this.tryOn,
    this.onEndTryOn,
    this.compact = false,
  });

  final MascotModel mascot;
  final double height;
  final double angle;
  final ValueChanged<double> onAngleChanged;
  final MascotAnimation animation;
  final int animationTrigger;
  final MascotAccessory? tryOn;
  final VoidCallback? onEndTryOn;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final secondary = dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final theme = MascotThemes.getById(mascot.themeId);
    final hex = mascot.appearance.colors['body'];
    final accent = hex == null
        ? theme.accentColor
        : Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? [AppColors.surfaceDark, AppColors.scaffoldDark]
                : [AppColors.surfaceLight, AppColors.cardLight],
          ),
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          border: Border.all(color: dark ? Colors.white12 : Colors.white),
        ),
        child: Column(
          children: [
            if (!compact)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ton Elyrii',
                        style: AppTextStyles.labelSmall(color: secondary),
                      ),
                    ),
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 15,
                      color: AppColors.readableAccent(accent, isDark: dark),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Aperçu 3D',
                      style: AppTextStyles.labelSmall(color: secondary),
                    ),
                  ],
                ),
              ),
            SizedBox(
              height: height,
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              accent.withValues(alpha: dark ? 0.18 : 0.15),
                              accent.withValues(alpha: 0),
                            ],
                            radius: 0.72,
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      label: 'Aperçu de ta mascotte. Fais glisser pour la tourner.',
                      child: MascotWithAccessories(
                        mascot: mascot,
                        config: Mascot3DConfig(
                          interactionEnabled: true,
                          useCameraOrbit: true,
                          cameraOrbitTheta: angle,
                          cameraOrbitPhi: 80,
                          cameraOrbitRadius: 110,
                          cameraTargetY: 0.96,
                        ),
                        width: constraints.maxWidth,
                        height: height,
                        animation: animation,
                        animationTrigger: animationTrigger,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!compact)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: LiquidGlassSegmentedControl<double>(
                      segments: {0.0: 'Face', 40.0: '3/4', 180.0: 'Dos'},
                      selectedValue: angle,
                      height: 44,
                      onValueChanged: onAngleChanged,
                    ),
                  ),
                ),
              ),
            if (tryOn != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                color: dark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.65),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 17,
                      color: secondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Essai · ${tryOn!.name}\nÀ débloquer avec tes défis',
                        style: AppTextStyles.labelSmall(color: primary),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Terminer l’essai',
                      onPressed: onEndTryOn,
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
