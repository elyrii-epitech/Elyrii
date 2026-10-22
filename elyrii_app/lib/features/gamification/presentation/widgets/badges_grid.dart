import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/accessible_action.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';

class BadgeItem {
  final String id;
  final String title;
  final String requirement;
  final IconData icon;
  final bool isUnlocked;
  const BadgeItem({
    required this.id,
    required this.title,
    required this.icon,
    this.requirement = '',
    this.isUnlocked = false,
  });
}

class BadgesGrid extends StatelessWidget {
  final List<BadgeItem> badges;
  final Function(BadgeItem) onBadgeTap;
  const BadgesGrid({super.key, required this.badges, required this.onBadgeTap});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = (constraints.maxWidth / (120 * scale)).floor().clamp(
        1,
        3,
      );
      final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
      final colors = Theme.of(context).colorScheme;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final badge in badges)
            SizedBox(
              width: width,
              child: AccessibleAction(
                label: '${badge.title}. ${badge.requirement}',
                value: badge.isUnlocked ? 'Débloqué' : 'À débloquer',
                excludeChildSemantics: true,
                onPressed: () => onBadgeTap(badge),
                child: LiquidGlassCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        badge.isUnlocked
                            ? badge.icon
                            : Icons.lock_outline_rounded,
                        color: colors.onSurfaceVariant,
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        badge.title,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.titleSmall(
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        badge.isUnlocked ? 'Débloqué' : 'À débloquer',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
