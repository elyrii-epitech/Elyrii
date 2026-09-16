import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';
import '../../../../core/widgets/mascot_with_accessories.dart';
import '../../../../core/config/mascot_animations.dart';
import '../../domain/models/breath_phase.dart';
import '../controllers/meditation_controller.dart';

/// Vue de synthèse et de gratitude affichée à la fin d'une session de respiration.
class MeditationSummaryView extends StatelessWidget {
  final MeditationController controller;

  const MeditationSummaryView({super.key, required this.controller});

  static const List<MoodOption> _moods = [
    MoodOption(
      Icons.sentiment_very_dissatisfied_rounded,
      'Pas bien',
      'verySad',
      Color(0xFF7BA3C7),
    ),
    MoodOption(
      Icons.sentiment_neutral_rounded,
      'Neutre',
      'neutral',
      Color(0xFFA39C96),
    ),
    MoodOption(
      Icons.sentiment_satisfied_rounded,
      'Bien',
      'happy',
      Color(0xFFA8D5BA),
    ),
    MoodOption(
      Icons.sentiment_satisfied_alt_rounded,
      'Apaisé(e)',
      'veryHappy',
      Color(0xFF7BC393),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final subtitleColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final accent = controller.selectedBreathingType.color;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.pageHorizontalPadding,
        vertical: AppDimensions.spacingLg,
      ),
      child: Column(
        children: [
          const SizedBox(height: AppDimensions.spacingMd),

          // Mascotte apaisée
          const SizedBox(
            width: 180,
            height: 180,
            child: MascotWithAccessories(
              config: Mascot3DConfig(
                autoRotate: false,
                interactionEnabled: false,
                showLoadingIndicator: false,
              ),
              // Réaction sobre après la séance terminée, puis retour idle.
              animation: MascotAnimations.celebrate,
              width: 180,
              height: 180,
            ),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

          const SizedBox(height: AppDimensions.spacingSm),

          Text(
            'Bravo, c\'est terminé !',
            style: AppTextStyles.headlineMedium(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 500.ms, delay: 200.ms),

          const SizedBox(height: AppDimensions.spacingXs),

          Text(
            'Tu as pris un moment pour toi,\net c\'est déjà une belle victoire.',
            style: AppTextStyles.bodyMedium(color: subtitleColor),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 500.ms, delay: 400.ms),

          const SizedBox(height: AppDimensions.spacingXl),

          // Carte de statistiques de la séance
          _buildStatsCard(isDark, textColor, subtitleColor, accent)
              .animate()
              .fadeIn(duration: 500.ms, delay: 500.ms)
              .slideY(begin: 0.15, end: 0),

          const SizedBox(height: AppDimensions.spacingXxl),

          // Question humeur après séance
          Text(
            'Comment te sens-tu maintenant ?',
            style: AppTextStyles.titleMedium(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 500.ms, delay: 600.ms),

          const SizedBox(height: AppDimensions.spacingLg),

          // Sélecteur d'humeur
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _moods.asMap().entries.map((entry) {
              final index = entry.key;
              final mood = entry.value;
              final selected = controller.selectedMoodIndex == index;

              return GestureDetector(
                onTap: () => controller.selectMood(index, mood.backendKey),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.18)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.02)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? AppColors.primary : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(mood.icon, size: 32, color: mood.color),
                      const SizedBox(height: 6),
                      Text(
                        mood.label,
                        style: AppTextStyles.labelSmall(
                          color: selected ? AppColors.primary : subtitleColor,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(
                duration: 350.ms,
                delay: Duration(milliseconds: 700 + (index * 80)),
              );
            }).toList(),
          ),

          const SizedBox(height: AppDimensions.spacingXxl),

          // Bouton retour au catalogue
          Center(
            child: LiquidGlassCard(
              onTap: () => controller.resetToSetup(),
              borderRadius: 30,
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
              color: AppColors.primary.withValues(alpha: 0.22),
              borderColor: AppColors.primary.withValues(alpha: 0.5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.refresh_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Nouvelle séance',
                    style: AppTextStyles.labelLarge(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 900.ms),

          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildStatsCard(
    bool isDark,
    Color textColor,
    Color subtitleColor,
    Color accent,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF201E24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatColumn(
            '${controller.selectedDurationMinutes} min',
            'Temps total',
            accent,
            isDark,
          ),
          Container(
            width: 1,
            height: 36,
            color: isDark ? Colors.white12 : Colors.black12,
          ),
          _buildStatColumn(
            '${controller.completedCycles}',
            'Cycles complets',
            AppColors.primary,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(
    String value,
    String label,
    Color valueColor,
    bool isDark,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
          ),
        ),
      ],
    );
  }
}
