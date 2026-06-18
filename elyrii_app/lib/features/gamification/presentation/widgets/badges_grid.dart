import 'package:flutter/material.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final badge = badges[index];

        return GestureDetector(
          onTap: () => onBadgeTap(badge),
          child: Opacity(
            opacity: badge.isUnlocked ? 1.0 : 0.35,
            child: LiquidGlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              color: badge.isUnlocked
                  ? AppColors.primary.withValues(alpha: isDark ? 0.1 : 0.05)
                  : null,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: badge.isUnlocked
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : Colors.black.withValues(alpha: 0.03)),
                    ),
                    child: Icon(
                      badge.isUnlocked
                          ? badge.icon
                          : Icons.hourglass_empty_rounded,
                      color: badge.isUnlocked
                          ? AppColors.primary
                          : (isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight),
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                  if (badge.isUnlocked)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Développé',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
