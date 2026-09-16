import 'package:flutter/material.dart';

import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/config/mascot_animations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_button.dart';
import '../../../../core/widgets/mascot_with_accessories.dart';
import '../../domain/models/breath_phase.dart';
import '../controllers/meditation_controller.dart';

/// Vue catalogue épurée pour choisir la technique et la durée de respiration.
class MeditationCatalogView extends StatelessWidget {
  final MeditationController controller;

  const MeditationCatalogView({super.key, required this.controller});

  static const List<int> _durations = [5, 10, 15];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final subtitleColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: AppDimensions.spacingSm),
              _buildMascotHero(isDark, textColor, subtitleColor),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.pageHorizontalPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (controller.backendError != null) ...[
                  const SizedBox(height: AppDimensions.spacingMd),
                  _buildSyncNotice(isDark),
                ],
                const SizedBox(height: AppDimensions.spacingLg),
                Text(
                  'Durée de la séance',
                  style: AppTextStyles.titleMedium(color: textColor),
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                _buildDurationSelector(isDark),
                const SizedBox(height: AppDimensions.spacingLg),
                Text(
                  'Techniques respiratoires',
                  style: AppTextStyles.titleMedium(color: textColor),
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                _buildBreathingTypeCards(isDark),
                const SizedBox(height: AppDimensions.spacingXl),
                LiquidGlassButton(
                  label: 'Commencer la séance',
                  icon: Icons.play_arrow_rounded,
                  style: LiquidGlassButtonStyle.filled,
                  isExpanded: true,
                  isLoading: controller.isStartingSession,
                  onPressed: () => controller.startSession(),
                ),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMascotHero(bool isDark, Color textColor, Color subtitleColor) {
    return Column(
      children: [
        const SizedBox(
          height: 160,
          child: MascotWithAccessories(
            // Mascotte posée et accueillante : pas de rotation présentoir,
            // un salut bienveillant à l'arrivée puis retour au calme.
            config: Mascot3DConfig(
              interactionEnabled: false,
              autoRotate: false,
            ),
            animation: MascotAnimations.greet,
            width: 160,
            height: 160,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingXxs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Prends un instant pour te recentrer et réguler ton système nerveux.',
            style: AppTextStyles.bodyMedium(color: subtitleColor),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildSyncNotice(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 18, color: AppColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              controller.backendError!,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationSelector(bool isDark) {
    return Row(
      children: _durations.map((duration) {
        final isSelected = controller.selectedDurationMinutes == duration;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: duration == _durations.last ? 0 : 10,
            ),
            child: GestureDetector(
              onTap: () => controller.setDuration(duration),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.18)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03)),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '$duration min',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? AppColors.primary
                            : (isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      duration == 5
                          ? 'Rapide'
                          : duration == 10
                          ? 'Idéal'
                          : 'Profond',
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? AppColors.primary
                            : (isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBreathingTypeCards(bool isDark) {
    return Column(
      children: BreathingType.values.map((type) {
        final isSelected = controller.selectedBreathingType == type;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => controller.setBreathingType(type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? type.color.withValues(alpha: isDark ? 0.18 : 0.12)
                    : (isDark
                          ? AppColors.cardDark.withValues(alpha: 0.5)
                          : Colors.white),
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                border: Border.all(
                  color: isSelected
                      ? type.color
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05)),
                  width: isSelected ? 2.0 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: type.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(type.icon, color: type.color, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                type.label,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: type.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${type.cycleDuration}s',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: type.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          type.description,
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
                  const SizedBox(width: 8),
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isSelected
                        ? type.color
                        : (isDark ? Colors.white24 : Colors.black26),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
