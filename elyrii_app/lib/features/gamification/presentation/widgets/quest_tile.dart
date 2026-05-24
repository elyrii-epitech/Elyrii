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

  const QuestTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.xpReward,
    this.isCompleted = false,
    this.onTap,
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
            borderColor: isCompleted
                ? AppColors.accent.withValues(alpha: 0.25)
                : null,
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
                        isCompleted ? 'Ce moment a ete vecu' : subtitle,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
