import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';

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
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          if (onTap != null) {
            HapticFeedback.lightImpact();
            onTap!();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: LiquidGlassCard(
            padding: const EdgeInsets.all(16),
            color: isCompleted
                ? (isDark
                    ? AppColors.accentDark.withValues(alpha: 0.12)
                    : AppColors.accentLight.withValues(alpha: 0.35))
                : null,
            borderColor:
                isCompleted ? AppColors.accent.withValues(alpha: 0.25) : null,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
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
                      : Icon(
                          icon,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                          size: 20,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isCompleted ? 'Ce moment a été vécu' : subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.xpBar.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '+$xpReward XP',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.xpBar
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
                      Flexible(
                        child: Text(
                          subtitle,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (xpReward > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.xpBar.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.xpBar.withValues(alpha: 0.4),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            '+$xpReward XP',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.amber[200]
                                  : Colors.amber[800],
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Barre de progression (uniquement si fournie)
                  if (progressFraction != null && !isCompleted) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progressFraction,
                              minHeight: 4,
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        if (progressText != null && progressText!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              progressText!,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textTertiaryLight,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            if (!isCompleted && progressFraction == null && onTap != null)
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
          ],
        ),
      ),
    );
  }
}
