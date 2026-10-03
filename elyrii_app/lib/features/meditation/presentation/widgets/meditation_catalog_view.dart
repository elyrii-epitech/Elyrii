import 'package:flutter/material.dart';
import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/config/mascot_animations.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/elyrii_page_header.dart';
import '../../../../core/widgets/glass/liquid_glass_kit.dart';
import '../../../../core/widgets/mascot_with_accessories.dart';
import '../../domain/models/meditation_exercise.dart';
import '../../domain/models/meditation_exercises.dart';
import '../controllers/meditation_controller.dart';
import 'meditation_duration_sheet.dart';
import 'meditation_sources_sheet.dart';

class MeditationCatalogView extends StatefulWidget {
  const MeditationCatalogView({super.key, required this.controller});
  final MeditationController controller;
  @override
  State<MeditationCatalogView> createState() => _MeditationCatalogViewState();
}

class _MeditationCatalogViewState extends State<MeditationCatalogView> {
  MeditationCategory? _category;
  static const _durations = [2, 5, 10, 15, 20, 30];
  MeditationController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final selected = controller.selectedExercise;
        final exercises = MeditationExercises.all
            .where((e) => _category == null || e.category == _category)
            .toList();
        return ElyriiPageFrame(
          header: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TON ESPACE',
                      style: AppTextStyles.labelSmall(
                        color: isDark
                            ? AppColors.primaryDark
                            : AppColors.primary,
                      ).copyWith(letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Méditation',
                        style: AppTextStyles.headlineLarge(color: text),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: 'Guide et références',
                child: LiquidGlassIconButton(
                  icon: Icons.info_outline_rounded,
                  onPressed: () => _showSources(selected),
                  size: 44,
                ),
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _preview(selected, text, secondary, isDark),
                    const SizedBox(height: 24),
                    Text(
                      'Du temps pour toi',
                      style: AppTextStyles.titleMedium(color: text),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Quelques minutes ou une longue pause : tu choisis.',
                      style: AppTextStyles.bodySmall(color: secondary),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final minutes in _durations)
                          _choice(
                            '$minutes min',
                            controller.selectedDurationMinutes == minutes,
                            () {
                              ElyriiHaptics.selection();
                              controller.setDuration(minutes);
                            },
                            isDark,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: LiquidGlassButton(
                        key: const Key('meditation-custom-duration'),
                        label:
                            _durations.contains(
                              controller.selectedDurationMinutes,
                            )
                            ? 'Choisir une autre durée'
                            : '${controller.selectedDurationMinutes} min · Modifier la durée',
                        icon: Icons.tune_rounded,
                        style: LiquidGlassButtonStyle.tinted,
                        onPressed: _chooseDuration,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Explorer les exercices',
                      style: AppTextStyles.titleMedium(color: text),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${MeditationExercises.all.length} pratiques, à ton rythme.',
                      style: AppTextStyles.bodySmall(color: secondary),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _choice(
                          'Tout',
                          _category == null,
                          () => setState(() => _category = null),
                          isDark,
                        ),
                        for (final category in MeditationCategory.values)
                          _choice(
                            category.label,
                            _category == category,
                            () => setState(() => _category = category),
                            isDark,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns =
                            constraints.maxWidth >= 340 &&
                                MediaQuery.textScalerOf(context).scale(1) <= 1.2
                            ? 2
                            : 1;
                        final width =
                            (constraints.maxWidth - 12 * (columns - 1)) /
                            columns;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final exercise in exercises)
                              SizedBox(
                                width: width,
                                child: _exerciseCard(
                                  exercise,
                                  selected?.id == exercise.id,
                                  text,
                                  secondary,
                                  isDark,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: LiquidGlassButton(
                      key: const Key('meditation-start'),
                      label: selected == null
                          ? 'Choisis un exercice'
                          : 'Commencer · ${controller.selectedDurationMinutes} min',
                      icon: Icons.play_arrow_rounded,
                      onPressed: selected == null
                          ? null
                          : () {
                              controller.startSession();
                            },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _choice(String label, bool selected, VoidCallback onTap, bool isDark) {
    final accent = isDark ? AppColors.primaryDark : AppColors.primary;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: AppTextStyles.labelMedium(
        color: selected
            ? accent
            : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
      ),
      backgroundColor: isDark
          ? AppColors.cardDark
          : Colors.white.withValues(alpha: 0.7),
      selectedColor: isDark
          ? AppColors.primaryDark.withValues(alpha: 0.18)
          : AppColors.primaryLight,
      side: BorderSide(
        color: selected
            ? accent.withValues(alpha: 0.5)
            : (isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
    );
  }

  Widget _preview(
    MeditationExercise? exercise,
    Color text,
    Color secondary,
    bool isDark,
  ) => LiquidGlassCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Row(
          children: [
            const SizedBox(
              width: 64,
              height: 64,
              child: MascotWithAccessories(
                config: Mascot3DConfig(
                  interactionEnabled: false,
                  autoRotate: false,
                ),
                animation: MascotAnimations.settle,
                width: 64,
                height: 64,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise?.title ?? 'À ton rythme',
                    style: AppTextStyles.titleMedium(color: text),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    exercise?.description ??
                        'Respiration ou guidage écrit, selon ton envie.',
                    style: AppTextStyles.bodySmall(color: secondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (exercise != null) ...[
          const SizedBox(height: 12),
          Text(
            exercise.guidanceLabel,
            style: AppTextStyles.labelMedium(
              color: AppColors.readableAccent(exercise.color, isDark: isDark),
            ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: isDark
                  ? AppColors.primaryDark
                  : AppColors.primary,
            ),
            onPressed: () => _showSources(exercise),
            icon: const Icon(Icons.menu_book_rounded, size: 16),
            label: const Text('Conseils et références'),
          ),
        ],
      ],
    ),
  );

  Widget _exerciseCard(
    MeditationExercise exercise,
    bool selected,
    Color text,
    Color secondary,
    bool isDark,
  ) {
    final ink = AppColors.readableAccent(exercise.color, isDark: isDark);
    return Semantics(
      selected: selected,
      button: true,
      label:
          '${exercise.title}. ${exercise.subtitle}. ${exercise.guidanceLabel}',
      child: LiquidGlassCard(
        onTap: () {
          ElyriiHaptics.selection();
          controller.setExercise(exercise);
        },
        color: selected
            ? exercise.color.withValues(alpha: isDark ? 0.14 : 0.12)
            : null,
        borderColor: selected ? ink.withValues(alpha: 0.6) : null,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: exercise.color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(exercise.icon, color: ink, size: 22),
                ),
                const Spacer(),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: ink, size: 22),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              exercise.title,
              style: AppTextStyles.titleSmall(
                color: text,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              exercise.subtitle,
              style: AppTextStyles.bodySmall(color: secondary),
            ),
            const SizedBox(height: 12),
            Text(
              exercise.guidanceLabel,
              style: AppTextStyles.labelSmall(color: ink),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseDuration() async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => MeditationDurationSheet(
        initialMinutes: controller.selectedDurationMinutes,
      ),
    );
    if (minutes != null && mounted) controller.setDuration(minutes);
  }

  void _showSources(MeditationExercise? exercise) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: MeditationSourcesSheet(exercise: exercise),
      ),
    );
  }
}
