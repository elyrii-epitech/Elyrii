import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';

/// Widget affichant une mini statistique
class MiniStatCard extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final bool isDark;
  final Color? accentColor;

  const MiniStatCard({
    super.key,
    required this.emoji,
    required this.value,
    required this.label,
    this.isDark = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingSm,
          vertical: AppDimensions.paddingMd,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF201E24) : Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color:
                    accentColor ??
                    (isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Row de mini statistiques
class MiniStatsRow extends StatelessWidget {
  final int entriesThisMonth;
  final int tagsUsed;
  final int currentStreak;
  final bool isDark;

  const MiniStatsRow({
    super.key,
    required this.entriesThisMonth,
    required this.tagsUsed,
    required this.currentStreak,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MiniStatCard(
          emoji: '📊',
          value: '$entriesThisMonth',
          label: 'ce mois',
          isDark: isDark,
          accentColor: AppColors.primary,
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        MiniStatCard(
          emoji: '🔥',
          value: '$currentStreak',
          label: 'jours',
          isDark: isDark,
          accentColor: AppColors.secondary,
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        MiniStatCard(
          emoji: '🏷️',
          value: '$tagsUsed',
          label: 'tags',
          isDark: isDark,
          accentColor: AppColors.accent,
        ),
      ],
    );
  }
}
