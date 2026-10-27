import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_sheet_route.dart';
import '../../../dashboard/presentation/mood_presentation.dart';
import '../controllers/meditation_controller.dart';

class MeditationSummarySheet extends StatelessWidget {
  final MeditationController controller;
  const MeditationSummarySheet({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final elapsed =
        controller.selectedDurationMinutes * 60 - controller.remainingSeconds;
    final minutes = elapsed ~/ 60;
    final seconds = elapsed % 60;
    final duration = minutes == 0
        ? '$seconds s'
        : seconds == 0
        ? '$minutes min'
        : '$minutes min $seconds s';
    return AppSheetPanel(
      title: "Résumé de la séance",
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimensions.spacing16),
              decoration: BoxDecoration(
                color: dark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppDimensions.radius20),
                border: Border.all(
                  color: dark ? AppColors.borderDark : AppColors.borderLight,
                  width: .5,
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(child: _stat(context, duration, 'Temps total')),
                    VerticalDivider(
                      width: AppDimensions.spacing32,
                      thickness: .5,
                      color: dark
                          ? AppColors.dividerDark
                          : AppColors.dividerLight,
                    ),
                    Expanded(
                      child: _stat(
                        context,
                        '${controller.completedCycles}',
                        'Cycles complets',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacing20),
            Text(
              'Comment te sens-tu maintenant ?',
              style: AppTextStyles.titleSmall(color: context.textPrimary),
            ),
            const SizedBox(height: AppDimensions.spacing12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final mood in MoodType.values)
                  Expanded(child: _mood(context, mood)),
              ],
            ),
            if (controller.backendError != null) ...[
              const SizedBox(height: AppDimensions.spacing16),
              Text(
                controller.backendError!,
                style: AppTextStyles.bodySmall(
                  color: AppColors.errorText(dark),
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.spacing20),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(
                  AppDimensions.meditationButtonHeight,
                ),
                backgroundColor: AppColors.primaryText(dark),
                foregroundColor: AppColors.onTint(dark),
                textStyle: AppTextStyles.labelLarge(),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) => Column(
    children: [
      Text(
        value,
        textAlign: TextAlign.center,
        style: AppTextStyles.headlineSmall(color: context.textPrimary),
      ),
      const SizedBox(height: AppDimensions.spacing8),
      Text(
        label,
        textAlign: TextAlign.center,
        style: AppTextStyles.bodySmall(color: context.textSecondary),
      ),
    ],
  );

  Widget _mood(BuildContext context, MoodType mood) {
    final selected = controller.selectedMoodIndex == mood.index;
    final color = mood.colorFor(Theme.of(context).brightness);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: mood.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => controller.selectMood(mood.index, mood.name),
        borderRadius: BorderRadius.circular(AppDimensions.radius16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacing4),
          child: Column(
            children: [
              AnimatedScale(
                scale: selected
                    ? AppDimensions.accueilMoodFaceSelectedScale
                    : 1,
                duration: reduced ? Duration.zero : AppMotion.moodFaceTap,
                curve: AppMotion.accueilEase,
                child: Container(
                  width: AppDimensions.controlSize,
                  height: AppDimensions.controlSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? color : color.withValues(alpha: .18),
                    border: selected
                        ? Border.all(
                            color: color.withValues(alpha: .3),
                            width: AppDimensions.spacing2,
                          )
                        : null,
                  ),
                  child: Icon(
                    mood.icon,
                    fill: 1,
                    size: AppDimensions.meditationIcon,
                    color: selected ? AppColors.onTint(true) : color,
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacing8),
              Text(
                mood.label,
                textAlign: TextAlign.center,
                style: selected
                    ? AppTextStyles.moodLabelSelected(
                        color: context.textPrimary,
                      )
                    : AppTextStyles.moodLabel(color: context.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
