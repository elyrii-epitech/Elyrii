import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';

class DailyStreakCard extends StatelessWidget {
  final int streakDays;
  final List<bool> weekHistory;

  const DailyStreakCard({
    super.key,
    required this.streakDays,
    required this.weekHistory,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LiquidGlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing20,
        vertical: AppDimensions.spacing16,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppDimensions.spacing12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ton rythme cette semaine',
                      style: AppTextStyles.titleMedium(
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacing2),
                    Text(
                      streakDays > 0
                          ? 'Tu as partagé $streakDays moments ensemble'
                          : 'Chaque jour compte, à ton rythme',
                      style: AppTextStyles.bodyMedium(
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final wasPresent = index < weekHistory.length
                  ? weekHistory[index]
                  : false;
              final dayInitial = _getDayInitial(index);

              return Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: wasPresent
                          ? AppColors.accent.withValues(alpha: 0.2)
                          : isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.black.withValues(alpha: 0.02),
                      shape: BoxShape.circle,
                      border: wasPresent
                          ? Border.all(
                              color: AppColors.accent.withValues(alpha: 0.4),
                              width: 1.5,
                            )
                          : Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.04),
                              width: 0.5,
                            ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      wasPresent ? Icons.wb_sunny_rounded : Icons.cloud_rounded,
                      size: 18,
                      color: wasPresent
                          ? AppColors.accent
                          : context.textTertiary.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacing8),
                  Text(
                    dayInitial,
                    style: AppTextStyles.bodySmall(
                      color: context.textSecondary,
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: AppDimensions.spacing20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.wb_sunny_rounded,
                size: 12,
                color: AppColors.accent,
              ),
              const SizedBox(width: AppDimensions.spacing4),
              Text(
                'Moments vécus',
                style: AppTextStyles.labelSmall(color: context.textTertiary),
              ),
              const SizedBox(width: AppDimensions.spacing24),
              Icon(
                Icons.cloud_rounded,
                size: 12,
                color: context.textTertiary.withValues(alpha: 0.5),
              ),
              const SizedBox(width: AppDimensions.spacing4),
              Text(
                'Repos & recharge',
                style: AppTextStyles.labelSmall(color: context.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getDayInitial(int index) {
    const days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return days[index % 7];
  }
}
