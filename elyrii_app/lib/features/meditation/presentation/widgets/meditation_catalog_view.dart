import 'package:flutter/material.dart';

import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/config/mascot_animations.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/elyrii_page_header.dart';
import '../../../../core/widgets/glass/liquid_glass_button.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';
import '../../../../core/widgets/glass/liquid_glass_sheet.dart';
import '../../../../core/widgets/mascot_with_accessories.dart';
import '../../domain/models/meditation_exercise.dart';
import '../../domain/models/meditation_exercises.dart';
import '../controllers/meditation_controller.dart';
import 'meditation_duration_sheet.dart';
import 'meditation_library_sheet.dart';
import 'meditation_practice_card.dart';

class MeditationCatalogView extends StatefulWidget {
  const MeditationCatalogView({super.key, required this.controller});

  final MeditationController controller;

  @override
  State<MeditationCatalogView> createState() => _MeditationCatalogViewState();
}

class _MeditationCatalogViewState extends State<MeditationCatalogView> {
  static const _featuredIds = [
    'facile',
    'carree',
    'mindful-breathing',
    'body-scan',
  ];

  MeditationController get controller => widget.controller;

  late (MeditationExercise?, int) _selection;

  (MeditationExercise?, int) get _currentSelection =>
      (controller.selectedExercise, controller.selectedDurationMinutes);

  @override
  void initState() {
    super.initState();
    _selection = _currentSelection;
    controller.addListener(_refreshSelection);
  }

  @override
  void didUpdateWidget(MeditationCatalogView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == controller) return;
    oldWidget.controller.removeListener(_refreshSelection);
    _selection = _currentSelection;
    controller.addListener(_refreshSelection);
  }

  @override
  void dispose() {
    controller.removeListener(_refreshSelection);
    super.dispose();
  }

  void _refreshSelection() {
    final selection = _currentSelection;
    // The session clock must not rebuild the hidden catalogue or its glass.
    if (selection == _selection) return;
    setState(() => _selection = selection);
  }

  List<MeditationExercise> _featured(MeditationExercise? selected) {
    final exercises = [
      for (final id in _featuredIds)
        MeditationExercises.all.firstWhere((exercise) => exercise.id == id),
    ];
    if (selected != null &&
        !exercises.any((exercise) => exercise.id == selected.id)) {
      exercises[0] = selected;
    }
    return exercises;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = context.textPrimary;
    final secondary = context.textSecondary;
    final accent = isDark ? AppColors.primaryDark : AppColors.primary;
    return ElyriiPageFrame.tab(
      key: const Key('meditation-catalog-scroll'),
      title: 'Méditation',
      actions: [_startAction(text)],
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            AppDimensions.pageHorizontalPadding,
            AppDimensions.spacing8,
            AppDimensions.pageHorizontalPadding,
            MediaQuery.paddingOf(context).bottom + AppDimensions.spacing24,
          ),
          sliver: SliverList.list(
            children: [
              _sessionCard(text, secondary, accent),
              const SizedBox(height: AppDimensions.spacing20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pratiques',
                      style: AppTextStyles.titleMedium(color: text),
                    ),
                  ),
                  TextButton(
                    key: const Key('meditation-browse'),
                    onPressed: _choosePractice,
                    style: TextButton.styleFrom(
                      foregroundColor: accent,
                      minimumSize: const Size(0, 44),
                      visualDensity: VisualDensity.standard,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacing8,
                      ),
                      textStyle: AppTextStyles.labelMedium(),
                    ),
                    child: const Text('Tout voir'),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacing12),
              MeditationPracticeGrid(
                key: const Key('meditation-featured'),
                exercises: _featured(controller.selectedExercise),
                selectedId: controller.selectedExercise?.id,
                onSelect: controller.setExercise,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sessionCard(Color text, Color secondary, Color accent) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(AppDimensions.spacing20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  controller.selectedExercise?.title ?? 'Choisis ta pratique',
                  style: AppTextStyles.titleMedium(color: text),
                ),
                const SizedBox(height: AppDimensions.spacing8),
                _durationControl(text, secondary, accent),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.spacing12),
          const ExcludeSemantics(child: _MeditationMascot()),
        ],
      ),
    );
  }

  Widget _durationControl(
    Color text,
    Color secondary,
    Color accent,
  ) => Semantics(
    button: true,
    excludeSemantics: true,
    onTap: _chooseDuration,
    label: 'Durée libre',
    container: true,
    value: controller.selectedDurationLabel,
    child: TextButton(
      key: const Key('meditation-custom-duration'),
      onPressed: _chooseDuration,
      style: TextButton.styleFrom(
        foregroundColor: text,
        minimumSize: const Size(0, 44),
        visualDensity: VisualDensity.standard,
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacing8),
        alignment: Alignment.centerLeft,
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, color: accent, size: 18),
          const SizedBox(width: AppDimensions.spacing8),
          Flexible(
            child: Text(
              controller.selectedDurationLabel,
              style: AppTextStyles.titleSmall(color: text),
            ),
          ),
          const SizedBox(width: AppDimensions.spacing8),
          Icon(Icons.keyboard_arrow_down_rounded, color: secondary, size: 16),
        ],
      ),
    ),
  );

  Widget _startAction(Color text) {
    final selected = controller.selectedExercise;
    final onPressed = selected == null ? null : controller.startSession;
    final label = selected == null
        ? 'Commencer, choisis une pratique'
        : 'Commencer ${selected.title}, ${controller.selectedDurationLabel}';

    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        key: const Key('meditation-start'),
        container: true,
        button: true,
        enabled: selected != null,
        excludeSemantics: true,
        label: label,
        onTap: onPressed,
        child: GestureDetector(
          onTap: onPressed,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The pinned bar has one row: large text keeps only the button.
              if (MediaQuery.textScalerOf(context).scale(13) <= 20) ...[
                Text(
                  'Commencer',
                  style: AppTextStyles.labelMedium(
                    color: selected == null
                        ? text.withValues(alpha: 0.4)
                        : text,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacing8),
              ],
              LiquidGlassIconButton(
                tooltip: 'Commencer la séance',
                icon: Icons.play_arrow_rounded,
                onPressed: onPressed,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _choosePractice() async {
    final exercise = await showLiquidGlassSheet<MeditationExercise>(
      context: context,
      useRootNavigator: true,
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      contentPadding: EdgeInsets.zero,
      scrollableBuilder: (context, scrollController) => MeditationLibrarySheet(
        scrollController: scrollController,
        selectedExercise: controller.selectedExercise,
      ),
    );
    if (exercise != null && mounted) controller.setExercise(exercise);
  }

  Future<void> _chooseDuration() async {
    ElyriiHaptics.selection();
    final duration = await showModalBottomSheet<Duration>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          MeditationDurationSheet(initialDuration: controller.selectedDuration),
    );
    if (duration != null && mounted) controller.setSessionDuration(duration);
  }
}

/// Keep the 3D surface stable when the selected practice or duration changes.
class _MeditationMascot extends StatelessWidget {
  const _MeditationMascot();

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final size = compact ? 64.0 : 92.0;
    return MascotWithAccessories(
      config: const Mascot3DConfig(
        interactionEnabled: false,
        autoRotate: false,
        showLoadingIndicator: false,
      ),
      animation: MascotAnimations.settle,
      width: size,
      height: size + 12,
    );
  }
}
