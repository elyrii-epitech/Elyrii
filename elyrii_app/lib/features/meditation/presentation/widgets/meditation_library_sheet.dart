import 'package:flutter/material.dart';

import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_button.dart';
import '../../domain/models/meditation_exercise.dart';
import '../../domain/models/meditation_exercises.dart';
import 'meditation_practice_card.dart';

class MeditationLibrarySheet extends StatefulWidget {
  const MeditationLibrarySheet({
    super.key,
    required this.scrollController,
    required this.selectedExercise,
  });

  final ScrollController scrollController;
  final MeditationExercise? selectedExercise;

  @override
  State<MeditationLibrarySheet> createState() => _MeditationLibrarySheetState();
}

class _MeditationLibrarySheetState extends State<MeditationLibrarySheet> {
  MeditationCategory? _category;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = context.textPrimary;
    final exercises = MeditationExercises.all
        .where(
          (exercise) => _category == null || exercise.category == _category,
        )
        .toList();

    return Column(
      key: const Key('meditation-library'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.pageHorizontalPadding,
            AppDimensions.spacing16,
            AppDimensions.pageHorizontalPadding,
            AppDimensions.spacing12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Toutes les pratiques',
                  style: AppTextStyles.titleLarge(color: text),
                ),
              ),
              const SizedBox(width: AppDimensions.spacing8),
              Semantics(
                key: const Key('meditation-library-close'),
                container: true,
                button: true,
                label: 'Fermer le catalogue',
                excludeSemantics: true,
                onTap: () => Navigator.pop(context),
                child: LiquidGlassIconButton(
                  tooltip: 'Fermer le catalogue',
                  icon: Icons.close_rounded,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppDimensions.pageHorizontalPadding,
              AppDimensions.spacing8,
              AppDimensions.pageHorizontalPadding,
              MediaQuery.paddingOf(context).bottom + AppDimensions.spacing24,
            ),
            children: [
              Theme(
                data: Theme.of(context)
                    .copyWith(canvasColor: Colors.transparent),
                child: Wrap(
                  spacing: AppDimensions.spacing8,
                  runSpacing: AppDimensions.spacing8,
                  children: [
                    _filter('Tout', null, isDark),
                    for (final category in MeditationCategory.values)
                      _filter(category.label, category, isDark),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spacing20),
              MeditationPracticeGrid(
                exercises: exercises,
                selectedId: widget.selectedExercise?.id,
                onSelect: (exercise) => Navigator.pop(context, exercise),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filter(String label, MeditationCategory? category, bool isDark) {
    final selected = _category == category;
    final accent = isDark ? AppColors.primaryDark : AppColors.primary;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      labelStyle: AppTextStyles.labelMedium(
        color: selected ? accent : context.textSecondary,
      ),
      backgroundColor: Colors.transparent,
      selectedColor: accent.withValues(alpha: 0.10),
      surfaceTintColor: Colors.transparent,
      side: BorderSide(
        color: selected ? accent.withValues(alpha: 0.22) : Colors.transparent,
      ),
      shape: const StadiumBorder(),
      onSelected: (_) {
        ElyriiHaptics.selection();
        setState(() => _category = category);
      },
    );
  }
}
