import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../meditation_practices.dart';

final _capsuleGlass = ui.ImageFilter.compose(
  outer: ColorFilter.saturation(1.7),
  inner: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
);

class MeditationDurationCapsule extends StatelessWidget {
  final int selected;
  final bool compact;
  final ValueChanged<int> onChanged;
  const MeditationDurationCapsule({
    super.key,
    required this.selected,
    required this.compact,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.capsuleCompact;
    final radius = BorderRadius.circular(AppDimensions.radius26);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: _capsuleGlass,
        child: AnimatedContainer(
          duration: duration,
          curve: AppMotion.accueilEase,
          padding: EdgeInsets.all(compact ? 0 : AppDimensions.spacing2),
          decoration: BoxDecoration(
            color: dark
                ? AppColors.glassBackgroundDark
                : AppColors.glassBackgroundLight,
            borderRadius: radius,
            border: Border.all(
              color: dark
                  ? AppColors.glassBorderDark
                  : AppColors.glassBorderLight,
              width: .5,
            ),
          ),
          child: Row(
            children: [
              for (final minutes in MeditationPractice.durationsAvailable)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: selected == minutes,
                    child: Material(
                      color: selected == minutes
                          ? AppColors.primaryText(dark)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusPill,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => onChanged(minutes),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: AppDimensions.controlSize,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.spacing4,
                              vertical: AppDimensions.spacing8,
                            ),
                            child: Center(
                              child: Text(
                                '$minutes min',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.labelMedium(
                                  color: selected == minutes
                                      ? AppColors.onTint(dark)
                                      : context.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
