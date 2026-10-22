import 'package:flutter/material.dart';

import '../../../../core/widgets/accessible_action.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../journal/data/models/journal_entry_model.dart';

class DashboardStreakCard extends StatelessWidget {
  final int streak;
  final bool isDark;
  final VoidCallback? onTap;

  const DashboardStreakCard({
    super.key,
    required this.streak,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const coral = Color(0xFFFF6B6B);

    return AccessibleAction(
      label: 'Ouvrir mes rituels',
      onPressed: onTap,
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: coral.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_fire_department_rounded,
                    color: coral,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'SÉRIE',
                    style: AppTextStyles.labelSmall(
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ).copyWith(letterSpacing: 0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '$streak ${streak > 1 ? 'jours' : 'jour'}',
              style: AppTextStyles.headlineSmall(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              streak > 0 ? 'Tu tiens le rythme !' : 'Commence aujourd\'hui',
              style: AppTextStyles.bodySmall(
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte Bento Pause Respiration avec bouton d'accès rapide.
class DashboardBreatheCard extends StatelessWidget {
  final bool isDark;
  final VoidCallback? onTap;

  const DashboardBreatheCard({
    super.key,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const lavender = AppColors.primary;

    return AccessibleAction(
      label: 'Ouvrir les exercices de respiration',
      onPressed: onTap,
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: lavender.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.air_rounded,
                    color: lavender,
                    size: 18,
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: lavender.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Démarrer',
                        style: AppTextStyles.labelSmall(
                          fontWeight: FontWeight.w700,
                          color: lavender,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.play_arrow_rounded,
                        size: 12,
                        color: lavender,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '2 min',
              style: AppTextStyles.headlineSmall(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Cohérence cardiaque',
              style: AppTextStyles.bodySmall(
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte Bento Pleine Largeur : Dernière entrée de journal.
class DashboardJournalCard extends StatelessWidget {
  final JournalEntryModel? lastEntry;
  final bool isDark;
  final VoidCallback? onTap;

  const DashboardJournalCard({
    super.key,
    required this.lastEntry,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AccessibleAction(
      label: 'Ouvrir mon journal',
      onPressed: onTap,
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Dernière réflexion',
                    style: AppTextStyles.titleSmall(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (lastEntry != null) ...[
              Text(
                lastEntry!.title.isNotEmpty ? lastEntry!.title : 'Sans titre',
                style: AppTextStyles.titleSmall(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                lastEntry!.content ?? '',
                style: AppTextStyles.bodyMedium(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ] else ...[
              Text(
                'Prends un instant pour poser tes pensées...',
                style: AppTextStyles.bodyMedium(
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Barre Bento Bilan & Progrès.
class DashboardReviewBar extends StatelessWidget {
  final bool isDark;
  final VoidCallback? onTap;

  const DashboardReviewBar({
    super.key,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AccessibleAction(
      label: 'Ouvrir mon bilan',
      onPressed: onTap,
      child: LiquidGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.insights_rounded,
                color: AppColors.accent,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Consulter mon bilan & progression',
                style: AppTextStyles.titleSmall(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
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

/// Squelette de chargement discret : shimmer doux aux couleurs de surface,
/// en remplacement de toute barre de progression brute.
