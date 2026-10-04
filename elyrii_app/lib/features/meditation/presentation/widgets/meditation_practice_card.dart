import 'package:flutter/material.dart';

import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';
import '../../domain/models/meditation_exercise.dart';

/// The same small glass cards used by the Coach activity catalogue.
class MeditationPracticeGrid extends StatelessWidget {
  const MeditationPracticeGrid({
    super.key,
    required this.exercises,
    required this.selectedId,
    required this.onSelect,
  });

  final List<MeditationExercise> exercises;
  final String? selectedId;
  final ValueChanged<MeditationExercise> onSelect;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth >= 280 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.2
          ? 2
          : 1;
      final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final exercise in exercises)
            SizedBox(
              width: width,
              child: MeditationPracticeCard(
                key: ValueKey('meditation-practice-${exercise.id}'),
                exercise: exercise,
                selected: selectedId == exercise.id,
                compact: columns == 1,
                onTap: () => onSelect(exercise),
              ),
            ),
        ],
      );
    },
  );
}

class MeditationPracticeCard extends StatelessWidget {
  const MeditationPracticeCard({
    super.key,
    required this.exercise,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final MeditationExercise exercise;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final secondary = isDark
        ? AppColors.textTertiaryDark
        : AppColors.textTertiaryLight;
    final ink = AppColors.readableAccent(exercise.color, isDark: isDark);
    final icon = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: exercise.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(exercise.icon, size: 18, color: ink),
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          exercise.title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          exercise.subtitle,
          style: TextStyle(fontSize: 12, height: 1.4, color: secondary),
        ),
      ],
    );
    final check = SizedBox(
      width: 20,
      height: 20,
      child: selected
          ? Icon(Icons.check_circle_rounded, size: 20, color: ink)
          : null,
    );
    void select() {
      ElyriiHaptics.selection();
      onTap();
    }

    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: '${exercise.title}. ${exercise.subtitle}',
      onTap: select,
      child: LiquidGlassCard(
        padding: EdgeInsets.zero,
        borderColor: selected ? ink.withValues(alpha: 0.55) : null,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: select,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: compact
                  ? Row(
                      children: [
                        icon,
                        const SizedBox(width: 12),
                        Expanded(child: copy),
                        const SizedBox(width: 8),
                        check,
                      ],
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 108),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [icon, const Spacer(), check]),
                          const SizedBox(height: 12),
                          copy,
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
