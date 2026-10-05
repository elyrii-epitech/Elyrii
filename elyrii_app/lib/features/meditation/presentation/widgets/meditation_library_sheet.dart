import 'package:flutter/material.dart';

import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../../core/theme/app_colors.dart';
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
    final text = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final exercises = MeditationExercises.all
        .where(
          (exercise) => _category == null || exercise.category == _category,
        )
        .toList();

    return Column(
      key: const Key('meditation-library'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Toutes les pratiques',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.8,
                    color: text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                key: const Key('meditation-library-close'),
                container: true,
                button: true,
                label: 'Fermer le catalogue',
                excludeSemantics: true,
                onTap: () => Navigator.pop(context),
                child: LiquidGlassIconButton(
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
              20,
              8,
              20,
              MediaQuery.paddingOf(context).bottom + 24,
            ),
            children: [
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(canvasColor: Colors.transparent),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _filter('Tout', null, isDark),
                    for (final category in MeditationCategory.values)
                      _filter(category.label, category, isDark),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        color: selected
            ? accent
            : isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight,
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
