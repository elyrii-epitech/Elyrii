import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';

class BadgeItem {
  final String id;
  final String title;
  final IconData icon;
  final bool isUnlocked;

  const BadgeItem({
    required this.id,
    required this.title,
    required this.icon,
    this.isUnlocked = false,
  });
}

class BadgesGrid extends StatelessWidget {
  final List<BadgeItem> badges;
  final Function(BadgeItem) onBadgeTap;

  const BadgesGrid({super.key, required this.badges, required this.onBadgeTap});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final badge = badges[index];
        return _buildBadgeTile(context, badge, index);
      },
    );
  }

  Widget _buildBadgeTile(BuildContext context, BadgeItem badge, int index) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => onBadgeTap(badge),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(8),
        color: badge.isUnlocked
            ? AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.05)
            : (isDark
                  ? Colors.white.withValues(alpha: 0.02)
                  : Colors.black.withValues(alpha: 0.02)),
        borderColor: badge.isUnlocked
            ? AppColors.primary.withValues(alpha: 0.3)
            : Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Badge Icon
            Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: badge.isUnlocked
                        ? const LinearGradient(
                            colors: [AppColors.primaryLight, AppColors.primary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: badge.isUnlocked
                        ? null
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.05)),
                    boxShadow: badge.isUnlocked
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    badge.isUnlocked ? badge.icon : Icons.lock_outline_rounded,
                    color: badge.isUnlocked
                        ? Colors.white
                        : (isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight),
                    size: 24,
                  ),
                )
                .animate(target: badge.isUnlocked ? 1 : 0)
                .shimmer(
                  duration: 2000.ms,
                  color: Colors.white.withValues(alpha: 0.5),
                ),

            const SizedBox(height: 8),

            // Badge Title
            Text(
              badge.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: badge.isUnlocked
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: badge.isUnlocked
                    ? (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight)
                    : (isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight),
              ),
            ),
          ],
        ),
      ),
    ).animate().scale(
      delay: (50 * index).ms,
      duration: 300.ms,
      curve: Curves.easeOutBack,
    );
  }
}
