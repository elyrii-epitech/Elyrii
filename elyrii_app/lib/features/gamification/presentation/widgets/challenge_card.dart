import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';
import '../../data/models/gamification_models.dart';

/// Carte affichée dans la section "Défis disponibles"
/// Montre le titre, la description et un bouton "Commencer"
class ChallengeAvailableCard extends StatelessWidget {
  final ChallengeTemplate challenge;
  final bool isStarting;
  final VoidCallback onStart;

  const ChallengeAvailableCard({
    super.key,
    required this.challenge,
    required this.onStart,
    this.isStarting = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icône
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Icon(
                challenge.icon,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),

            // Titre + description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    challenge.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  if (challenge.description != null &&
                      challenge.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      challenge.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Bouton Commencer
            isStarting
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : GestureDetector(
                    onTap: onStart,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Commencer',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideX(begin: 0.05, end: 0);
  }
}
