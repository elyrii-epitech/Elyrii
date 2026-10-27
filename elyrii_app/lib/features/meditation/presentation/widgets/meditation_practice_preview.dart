import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_dimensions.dart';
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
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      heightFactor: 1,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDimensions.meditationPreviewWidth,
          ),
          child: Material(
            color: practice.color,
            borderRadius: BorderRadius.circular(AppDimensions.radius28),
            clipBehavior: Clip.antiAlias,
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: practice.title,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.spacing24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          practice.icon,
                          fill: 1,
                          color: Colors.white,
                          size: AppDimensions.meditationBandIcon,
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: "Fermer l'aperçu",
                          onPressed: () => Navigator.of(context).pop(false),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: .14,
                            ),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.square(
                              AppDimensions.controlSize,
                            ),
                          ),
                          icon: const Icon(
                            Symbols.close_rounded,
                            size: AppDimensions.iconMd,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacing20),
                    Text(
                      practice.title,
                      style: AppTextStyles.titleLarge(color: Colors.white),
                    ),
                    const SizedBox(height: AppDimensions.spacing8),
                    Text(
                      practice.exercise.isBreathing
                          ? practice.rhythm.replaceAll('·', ' · ')
                          : 'Guidage écrit',
                      style: AppTextStyles.bodySmall(
                        color: Colors.white.withValues(alpha: .8),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacing20),
                    Text(
                      practice.description,
                      style: AppTextStyles.bodyMedium(color: Colors.white),
                    ),
                    const SizedBox(height: AppDimensions.spacing12),
                    Text(
                      practice.exercise.practiceTip,
                      style: AppTextStyles.bodyMedium(
                        color: Colors.white.withValues(alpha: .85),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacing24),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: practice.color,
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
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
