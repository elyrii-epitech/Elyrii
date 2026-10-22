import 'package:flutter/material.dart';

import '../../../../core/widgets/accessible_action.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../journal/data/models/journal_entry_model.dart';

class DashboardStreakCard extends StatelessWidget {
  final int streak;
  final VoidCallback? onTap;

  const DashboardStreakCard({super.key, required this.streak, this.onTap});

  @override
  Widget build(BuildContext context) {
    const coral = Color(0xFFFF6B6B);

    return AccessibleAction(
      label: 'Ouvrir mes rituels',
      onPressed: onTap,
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppDimensions.spacing8),
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
                const SizedBox(width: AppDimensions.spacing8),
                Flexible(
                  child: Text(
                    'SÉRIE',
                    style: AppTextStyles.badge(color: context.textTertiary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing16),
            Text(
              '$streak ${streak > 1 ? 'jours' : 'jour'}',
              style: AppTextStyles.headlineSmall(color: context.textPrimary),
            ),
            const SizedBox(height: AppDimensions.spacing4),
            Text(
              streak > 0 ? 'Tu tiens le rythme !' : 'Commence aujourd\'hui',
              style: AppTextStyles.bodySmall(color: context.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte Bento Pause Respiration avec bouton d'accès rapide.
class DashboardBreatheCard extends StatelessWidget {
  final VoidCallback? onTap;

  const DashboardBreatheCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const lavender = AppColors.primary;

    return AccessibleAction(
      label: 'Ouvrir les exercices de respiration',
      onPressed: onTap,
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppDimensions.spacing4,
              runSpacing: AppDimensions.spacing8,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppDimensions.spacing8),
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
                    horizontal: AppDimensions.spacing8,
                    vertical: AppDimensions.spacing2,
                  ),
                  decoration: BoxDecoration(
                    color: lavender.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppDimensions.radius8),
                  ),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Démarrer',
                        style: AppTextStyles.badge(color: lavender),
                      ),
                      const SizedBox(width: AppDimensions.spacing2),
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
            const SizedBox(height: AppDimensions.spacing16),
            Text(
              '2 min',
              style: AppTextStyles.headlineSmall(color: context.textPrimary),
            ),
            const SizedBox(height: AppDimensions.spacing4),
            Text(
              'Cohérence cardiaque',
              style: AppTextStyles.bodySmall(color: context.textSecondary),
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
  final VoidCallback? onTap;

  const DashboardJournalCard({
    super.key,
    required this.lastEntry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AccessibleAction(
      label: 'Ouvrir mon journal',
      onPressed: onTap,
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppDimensions.spacing8),
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
                const SizedBox(width: AppDimensions.spacing8),
                Expanded(
                  child: Text(
                    'Dernière réflexion',
                    style: AppTextStyles.titleSmall(color: context.textPrimary),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacing8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: context.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing12),
            if (lastEntry != null) ...[
              Text(
                lastEntry!.title.isNotEmpty ? lastEntry!.title : 'Sans titre',
                style: AppTextStyles.titleSmall(color: context.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppDimensions.spacing4),
              Text(
                lastEntry!.content ?? '',
                style: AppTextStyles.bodyMedium(color: context.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ] else ...[
              Text(
                'Prends un instant pour poser tes pensées...',
                style: AppTextStyles.bodyMedium(color: context.textTertiary)
                    .copyWith(fontStyle: FontStyle.italic),
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
  final VoidCallback? onTap;

  const DashboardReviewBar({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AccessibleAction(
      label: 'Ouvrir mon bilan',
      onPressed: onTap,
      child: LiquidGlassCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing16,
          vertical: AppDimensions.spacing16,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimensions.spacing8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppDimensions.radius8),
              ),
              child: const Icon(
                Icons.insights_rounded,
                color: AppColors.accent,
                size: 18,
              ),
            ),
            const SizedBox(width: AppDimensions.spacing12),
            Expanded(
              child: Text(
                'Consulter mon bilan & progression',
                style: AppTextStyles.titleSmall(color: context.textPrimary),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// Squelette de chargement discret : shimmer doux aux couleurs de surface,
/// en remplacement de toute barre de progression brute.
