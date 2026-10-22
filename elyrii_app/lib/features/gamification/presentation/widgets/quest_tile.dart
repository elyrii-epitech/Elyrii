import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';

class QuestTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final int xpReward;
  final bool isCompleted;
  final VoidCallback? onTap;

  /// Si fourni, affiche une barre de progression (valeur entre 0.0 et 1.0)
  final double? progressFraction;

  /// Texte affiché sous la barre, ex: "3 / 7"
  final String? progressText;

  const QuestTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.xpReward,
    this.isCompleted = false,
    this.onTap,
    this.progressFraction,
    this.progressText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing12),
      child: GestureDetector(
        onTap: () {
          if (onTap != null) {
            ElyriiHaptics.light();
            onTap!();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: LiquidGlassCard(
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            color: isCompleted
                ? (isDark
                      ? AppColors.accentDark.withValues(alpha: 0.12)
                      : AppColors.accentLight.withValues(alpha: 0.35))
                : null,
            borderColor: isCompleted
                ? AppColors.accent.withValues(alpha: 0.25)
                : null,
            child: Row(
              children: [
                // Left icon circle
                Container(
                  padding: const EdgeInsets.all(AppDimensions.spacing12),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.accent.withValues(alpha: 0.15)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.03)),
                    shape: BoxShape.circle,
                  ),
                  child: isCompleted
                      ? const Icon(
                          Icons.favorite_rounded,
                          color: AppColors.accent,
                          size: 20,
                        )
                      : Icon(icon, color: context.textSecondary, size: 20),
                ),
                const SizedBox(width: AppDimensions.spacing16),

                // Title, Subtitle, and Progress Bar
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.titleSmall(
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacing4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              isCompleted ? 'Ce moment a été vécu' : subtitle,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall(
                                color: context.textTertiary,
                              ),
                            ),
                          ),
                          if (xpReward > 0 && !isCompleted) ...[
                            const SizedBox(width: AppDimensions.spacing8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimensions.spacing8,
                                vertical: AppDimensions.spacing2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.xpBar.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radius8,
                                ),
                                border: Border.all(
                                  color: AppColors.xpBar.withValues(alpha: 0.4),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                '+$xpReward XP',
                                style: AppTextStyles.badge(
                                  color: isDark
                                      ? Colors.amber[200]
                                      : Colors.amber[800],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      // Progress bar (if provided)
                      if (progressFraction != null && !isCompleted) ...[
                        const SizedBox(height: AppDimensions.spacing8),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusPill,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusPill,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: (progressFraction ?? 0.0)
                                          .clamp(0.0, 1.0),
                                      child: Container(
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(
                                            AppDimensions.radiusPill,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (progressText != null &&
                                progressText!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: AppDimensions.spacing8,
                                ),
                                child: Text(
                                  progressText!,
                                  overflow: TextOverflow.clip,
                                  style: AppTextStyles.labelMedium(
                                    color: context.textTertiary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppDimensions.spacing12),

                // Right arrow (if tappable and not completed)
                if (!isCompleted && progressFraction == null && onTap != null)
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: context.textTertiary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
