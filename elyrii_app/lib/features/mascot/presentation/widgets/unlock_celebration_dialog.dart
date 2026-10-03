import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/glass/elyrii_glass_surface.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_button.dart';
import '../../data/models/mascot_accessory.dart';

/// Dialogue de célébration lorsqu'un nouvel accessoire est débloqué.
class UnlockCelebrationDialog extends StatefulWidget {
  final MascotAccessory accessory;
  final int unlockedCount;
  final bool isDark;
  final VoidCallback onEquip;

  const UnlockCelebrationDialog({
    super.key,
    required this.accessory,
    this.unlockedCount = 1,
    required this.isDark,
    required this.onEquip,
  });

  @override
  State<UnlockCelebrationDialog> createState() =>
      _UnlockCelebrationDialogState();
}

class _UnlockCelebrationDialogState extends State<UnlockCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final acc = widget.accessory;
    final celebrationMessage = widget.unlockedCount > 1
        ? '${widget.unlockedCount} nouveaux accessoires rejoignent ta garde-robe ! '
              '${acc.description}'
        : '${acc.requiredChallenges == 1 ? 'Bravo pour ton premier défi terminé' : 'Bravo pour tes ${acc.unlockLabel}'} ! '
              '${acc.description}';
    final titleColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final bodyColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    const confettiColors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.accent,
      AppColors.xpBar,
      AppColors.success,
    ];

    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                constraints: const BoxConstraints(maxWidth: 340),
                child: ElyriiGlassSurface(
                  role: GlassRole.dialog,
                  borderRadius: BorderRadius.circular(28),
                  child: AnimatedBuilder(
                    animation: _shimmerCtrl,
                    builder: (context, _) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Contenu de la carte
                          Container(
                            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Badge Récompense débloquée
                                Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(
                                          alpha: isDark ? 0.18 : 0.14,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: AppColors.success.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.workspace_premium_rounded,
                                            size: 14,
                                            color: AppColors.success,
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              widget.unlockedCount > 1
                                                  ? 'RÉCOMPENSES DÉBLOQUÉES'
                                                  : 'RÉCOMPENSE DÉBLOQUÉE',
                                              textAlign: TextAlign.center,
                                              style: AppTextStyles.labelSmall(
                                                color: AppColors.successDark,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(delay: 200.ms)
                                    .slideY(begin: -0.3),
                                const SizedBox(height: 24),

                                // Halo + emoji de l'accessoire
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 110,
                                      height: 110,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            AppColors.primary.withValues(
                                              alpha:
                                                  0.25 +
                                                  0.15 *
                                                      (0.5 +
                                                          0.5 *
                                                              _shimmerCtrl
                                                                  .value),
                                            ),
                                            AppColors.accent.withValues(
                                              alpha: 0.08,
                                            ),
                                            Colors.transparent,
                                          ],
                                          stops: const [0.0, 0.6, 1.0],
                                        ),
                                      ),
                                    ),
                                    Text(
                                          acc.emoji,
                                          style: const TextStyle(fontSize: 56),
                                        )
                                        .animate()
                                        .fadeIn(duration: 500.ms)
                                        .scale(
                                          begin: const Offset(0.3, 0.3),
                                          end: const Offset(1, 1),
                                          curve: Curves.elasticOut,
                                          delay: 100.ms,
                                        ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                Text(
                                      acc.name,
                                      style: AppTextStyles.headlineSmall(
                                        color: titleColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    )
                                    .animate()
                                    .fadeIn(delay: 300.ms)
                                    .slideY(begin: 0.15),
                                const SizedBox(height: 10),
                                Text(
                                      celebrationMessage,
                                      style: AppTextStyles.bodyMedium(
                                        color: bodyColor,
                                      ).copyWith(height: 1.55),
                                      textAlign: TextAlign.center,
                                    )
                                    .animate()
                                    .fadeIn(delay: 450.ms)
                                    .slideY(begin: 0.15),
                                const SizedBox(height: 28),

                                // Bouton équiper
                                LiquidGlassButton(
                                      label: 'L\'équiper maintenant',
                                      icon: Icons.check_rounded,
                                      isExpanded: true,
                                      onPressed: widget.onEquip,
                                    )
                                    .animate()
                                    .fadeIn(delay: 600.ms)
                                    .slideY(begin: 0.2),
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'Plus tard',
                                    style: AppTextStyles.bodyMedium(
                                      color: bodyColor,
                                    ),
                                  ),
                                ).animate().fadeIn(delay: 700.ms),
                              ],
                            ),
                          ),

                          // Particules confettis
                          ...List.generate(16, (i) {
                            final angle =
                                (i / 16) * math.pi * 2 +
                                _shimmerCtrl.value * 0.8;
                            final radius =
                                80.0 +
                                30.0 *
                                    (0.5 +
                                        0.5 *
                                            math.sin(
                                              _shimmerCtrl.value * 2 * math.pi +
                                                  i,
                                            ));
                            final dx = radius * math.cos(angle);
                            final dy = radius * math.sin(angle);
                            return Positioned(
                              left: 150 + dx,
                              top: 80 + dy,
                              child:
                                  Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color:
                                              confettiColors[i %
                                                  confettiColors.length],
                                          shape: i % 2 == 0
                                              ? BoxShape.circle
                                              : BoxShape.rectangle,
                                          borderRadius: i % 2 == 0
                                              ? null
                                              : BorderRadius.circular(1),
                                        ),
                                      )
                                      .animate(onPlay: (c) => c.repeat())
                                      .fadeIn(delay: (i * 60).ms)
                                      .scale(
                                        begin: const Offset(0.5, 0.5),
                                        end: const Offset(1, 1),
                                      ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
