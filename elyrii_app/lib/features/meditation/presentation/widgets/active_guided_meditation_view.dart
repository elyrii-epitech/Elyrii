import 'package:flutter/material.dart';

import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/config/mascot_animations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/elyrii_page_header.dart';
import '../../../../core/widgets/glass/liquid_glass_kit.dart';
import '../../../../core/widgets/mascot_with_accessories.dart';
import '../controllers/meditation_controller.dart';

class ActiveGuidedMeditationView extends StatelessWidget {
  const ActiveGuidedMeditationView({
    super.key,
    required this.controller,
    required this.onRequestExit,
  });
  final MeditationController controller;
  final VoidCallback onRequestExit;

  @override
  Widget build(BuildContext context) {
    final exercise = controller.selectedExercise!;
    final step = controller.currentGuidanceStep;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final ink = AppColors.readableAccent(exercise.color, isDark: isDark);
    final minutes = controller.remainingSeconds ~/ 60;
    final seconds = (controller.remainingSeconds % 60).toString().padLeft(
      2,
      '0',
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: ElyriiPageHeader(
            title: exercise.title,
            subtitle: controller.isPaused
                ? 'En pause'
                : '$minutes:$seconds restantes',
            leading: Semantics(
              label: 'Interrompre la séance',
              button: true,
              child: LiquidGlassIconButton(
                icon: Icons.close_rounded,
                onPressed: onRequestExit,
                size: 44,
              ),
            ),
            trailing: Semantics(
              label: controller.isPaused
                  ? 'Reprendre la séance'
                  : 'Mettre en pause',
              button: true,
              child: LiquidGlassIconButton(
                icon: controller.isPaused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                onPressed: controller.isPaused
                    ? controller.resumeSession
                    : controller.pauseSession,
                color: ink,
                size: 44,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: controller.progressRatio,
              minHeight: 5,
              color: ink,
              backgroundColor: exercise.color.withValues(alpha: 0.15),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              children: [
                const SizedBox(
                  width: 152,
                  height: 152,
                  child: MascotWithAccessories(
                    config: Mascot3DConfig(
                      interactionEnabled: false,
                      autoRotate: false,
                    ),
                    animation: MascotAnimations.settle,
                    width: 152,
                    height: 152,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Étape ${controller.currentGuidanceStepIndex + 1} sur ${exercise.steps.length}',
                  style: AppTextStyles.labelMedium(color: ink),
                ),
                const SizedBox(height: 12),
                Text(
                  step.title,
                  key: const Key('meditation-guidance-title'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineSmall(color: text),
                ),
                const SizedBox(height: 16),
                Text(
                  step.instruction,
                  key: const Key('meditation-guidance-instruction'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge(
                    color: secondary,
                  ).copyWith(height: 1.6),
                ),
                const SizedBox(height: 24),
                Text(
                  'Ton souffle reste naturel.',
                  style: AppTextStyles.bodySmall(color: secondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
