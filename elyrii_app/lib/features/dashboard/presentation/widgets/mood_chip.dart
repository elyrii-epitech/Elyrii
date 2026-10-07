import 'package:flutter/material.dart';

import '../../../../core/widgets/accessible_action.dart';
import '../../../../core/theme/app_colors.dart';
import '../mood_presentation.dart';

/// Puce de mood interactive avec micro-rebond élastique Apple, haptique et halo.
class DashboardMoodChip extends StatelessWidget {
  final MoodType mood;
  final bool isSelected;
  final bool isDark;
  final VoidCallback? onTap;

  const DashboardMoodChip({
    super.key,
    required this.mood,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final moodColor = mood.color;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      selected: isSelected,
      child: AccessibleAction(
        label: mood.label,
        onPressed: onTap,
        child: AnimatedScale(
          scale: isSelected && !reduceMotion ? 1.08 : 1.0,
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 140),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? moodColor.withValues(alpha: isDark ? 0.25 : 0.18)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? moodColor.withValues(alpha: 0.6)
                    : Colors.transparent,
                width: 1.8,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: moodColor.withValues(
                          alpha: isDark ? 0.35 : 0.20,
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              mood.icon,
              size: isSelected ? 26 : 22,
              color: isSelected
                  ? moodColor
                  : (isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight),
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte Bento Série & Régularité (esprit Apple Fitness).
