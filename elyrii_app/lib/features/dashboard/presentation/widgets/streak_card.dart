import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/glass_container.dart';

/// Widget affichant la série de jours consécutifs avec effet glassmorphism
class StreakCard extends StatelessWidget {
  final int streakCount;
  final bool isDark;

  const StreakCard({
    super.key,
    required this.streakCount,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      isDark: isDark,
      borderRadius: AppDimensions.radiusMd,
      intensity: GlassIntensity.medium,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMd,
        vertical: AppDimensions.paddingSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icône feu animée
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.9, end: 1.1),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: const Text(
              '🔥',
              style: TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: AppDimensions.spacingXs),
          // Compteur
          Text(
            '$streakCount',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingXxs),
          Text(
            streakCount > 1 ? 'jours' : 'jour',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
