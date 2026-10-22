import '../../../../core/accessibility/motion.dart';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';
import '../../data/models/gamification_models.dart';

/// Carte affichant une proposition bienveillante générée par Elyrii.
///
/// Refonte Apple HIG :
/// - Palette cohérente de l'application ([AppColors.primary]), suppression
///   des teintes `purpleAccent` brutes.
/// - Boutons sous forme de capsules tactiles discrètes (remplace
///   `TextButton`/`ElevatedButton` Material).
/// - État de traitement matérialisé par un shimmer doux (aucun spinner
///   Material).
class AiProposalCard extends StatelessWidget {
  final UserChallenge proposal;
  final bool isProcessing;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const AiProposalCard({
    super.key,
    required this.proposal,
    required this.onAccept,
    required this.onReject,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing12),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icône
                Container(
                  padding: const EdgeInsets.all(AppDimensions.spacing12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    proposal.displayIcon,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacing16),

                // Titre + badge Elyrii
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              proposal.displayTitle,
                              style: AppTextStyles.titleSmall(
                                color: context.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.spacing8,
                              vertical: AppDimensions.spacing2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radius8,
                              ),
                            ),
                            child: Text(
                              'IA',
                              style: AppTextStyles.badge(
                                color: AppColors.readableAccent(
                                  AppColors.primary,
                                  isDark:
                                      Theme.of(context).brightness ==
                                      Brightness.dark,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (proposal.displayDescription.isNotEmpty) ...[
                        const SizedBox(height: AppDimensions.spacing4),
                        Text(
                          proposal.displayDescription,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall(
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing16),
            // Actions : capsules tactiles coordonnées
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isProcessing) ...[
                  GestureDetector(
                    onTap: () {
                      ElyriiHaptics.light();
                      onReject();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacing16,
                        vertical: AppDimensions.spacing8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radius20,
                        ),
                      ),
                      child: Text(
                        'Plus tard',
                        style: AppTextStyles.bodySmall(
                          color: context.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacing8),
                ],
                isProcessing
                    ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.spacing16,
                              vertical: AppDimensions.spacing8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radius20,
                              ),
                            ),
                            child: Text(
                              'Un instant…',
                              style: AppTextStyles.labelMedium(
                                color: Colors.white,
                              ),
                            ),
                          )
                          .animateRespectingMotion(
                            context,
                            onPlay: (c) => c.repeat(),
                          )
                          .shimmer(
                            duration: 1000.ms,
                            color: Colors.white.withValues(alpha: 0.5),
                          )
                    : GestureDetector(
                        onTap: () {
                          ElyriiHaptics.light();
                          onAccept();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.spacing16,
                            vertical: AppDimensions.spacing8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radius20,
                            ),
                          ),
                          child: Text(
                            'Accepter',
                            style: AppTextStyles.labelMedium(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
