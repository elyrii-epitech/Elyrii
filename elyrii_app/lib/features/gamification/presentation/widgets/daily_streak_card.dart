import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ton rythme cette semaine',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      streakDays > 0
                          ? 'Vous avez partage $streakDays moments ensemble'
                          : 'Elyrii est la quand tu en as besoin',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final wasPresent =
                  index < weekHistory.length ? weekHistory[index] : false;
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
                          : (isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight).withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dayInitial,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              )
                  .animate()
                  .fadeIn(delay: (80 * index).ms)
                  .slideY(begin: 0.15, end: 0);
            }),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wb_sunny_rounded, size: 12, color: AppColors.accent),
              const SizedBox(width: 4),
              Text(
                'Moments vécus',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 24),
              Icon(Icons.cloud_rounded, size: 12, color: (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight).withValues(alpha: 0.5)),
              const SizedBox(width: 4),
              Text(
                'Repos & recharge',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  fontWeight: FontWeight.w500,
                ),
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
