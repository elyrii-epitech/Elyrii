import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_sheet_route.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../meditation_practices.dart';

class MeditationPracticePreview extends StatelessWidget {
  final MeditationPractice practice;
  final int duration;
  const MeditationPracticePreview({
    super.key,
    required this.practice,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) => AppSheetPanel(
    title: practice.title,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          practice.icon,
          fill: 1,
          color: practice.color,
          size: AppDimensions.meditationBandIcon,
        ),
        const SizedBox(height: AppDimensions.spacing20),
        Text(
          practice.exercise.isBreathing
              ? practice.rhythm.replaceAll('·', ' · ')
              : 'À ton rythme',
          style: AppTextStyles.bodySmall(color: context.textSecondary),
        ),
        const SizedBox(height: AppDimensions.spacing20),
        Text(
          practice.description,
          style: AppTextStyles.bodyMedium(color: context.textPrimary),
        ),
        const SizedBox(height: AppDimensions.spacing12),
        Text(
          practice.exercise.practiceTip,
          style: AppTextStyles.bodyMedium(color: context.textSecondary),
        ),
        const SizedBox(height: AppDimensions.spacing24),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(
              AppDimensions.meditationButtonHeight,
            ),
            textStyle: AppTextStyles.labelLarge(),
          ),
          icon: const Icon(
            Symbols.play_arrow_rounded,
            fill: 1,
            size: AppDimensions.iconSm,
          ),
          label: Text('Commencer · $duration min'),
        ),
      ],
    ),
  );
}
