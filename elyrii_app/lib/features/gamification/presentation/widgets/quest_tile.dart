import 'package:flutter/material.dart';
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LiquidGlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        color: isCompleted
            ? (isDark
                ? AppColors.successDark.withValues(alpha: 0.15)
                : AppColors.successLight.withValues(alpha: 0.4))
            : null,
        borderColor: isCompleted
            ? (isDark
                ? AppColors.successDark.withValues(alpha: 0.3)
                : AppColors.success.withValues(alpha: 0.3))
            : null,
        child: Row(
          children: [
            // Icon Container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.success.withValues(alpha: 0.2)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03)),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted
                      ? AppColors.success.withValues(alpha: 0.3)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05)),
                  width: 1,
                ),
              ),
              child: Icon(
                isCompleted ? Icons.check_rounded : icon,
                color: isCompleted
                    ? AppColors.success
                    : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),

            // Text Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                      color: isDark
                          ? (isCompleted
                              ? AppColors.textSecondaryDark
                              : AppColors.textPrimaryDark)
                          : (isCompleted
                              ? AppColors.textSecondaryLight
                              : AppColors.textPrimaryLight),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // XP Badge
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
                            color:
                                isDark ? Colors.amber[200] : Colors.amber[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (!isCompleted && onTap != null)
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
