import 'package:flutter/material.dart';

import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/config/mascot_animations.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../../core/glass/elyrii_glass_surface.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/elyrii_page_header.dart';
import '../../../../core/widgets/glass/liquid_glass_button.dart';
import '../../../../core/widgets/mascot_with_accessories.dart';
import '../../domain/models/meditation_exercise.dart';
import '../../domain/models/meditation_exercises.dart';
import '../controllers/meditation_controller.dart';
import 'meditation_duration_sheet.dart';

class MeditationCatalogView extends StatefulWidget {
  const MeditationCatalogView({super.key, required this.controller});

  final MeditationController controller;

  @override
  State<MeditationCatalogView> createState() => _MeditationCatalogViewState();
}

class _MeditationCatalogViewState extends State<MeditationCatalogView> {
  MeditationCategory? _category;
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
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Méditation',
                        style: AppTextStyles.headlineLarge(color: text),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  key: const Key('meditation-catalog-scroll'),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _welcome(text, secondary),
                    const SizedBox(height: 24),
                    _durationControl(text, secondary, isDark),
                    const SizedBox(height: 28),
                    Text(
                      'Choisis ta pratique',
                      style: AppTextStyles.titleMedium(
                        color: text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _filter('Tout', null, isDark),
                        for (final category in MeditationCategory.values)
                          _filter(category.label, category, isDark),
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
                                  compact: columns == 1,
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
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: Semantics(
                    button: true,
                    enabled: selected != null,
                    child: LiquidGlassButton(
                      key: const Key('meditation-start'),
                      isExpanded: true,
                      // iOS keeps the primary action visible while it is
                      // unavailable, but lets the material recede instead
                      // of tinting a disabled control with the accent.
                      style: selected == null
                          ? LiquidGlassButtonStyle.gray
                          : LiquidGlassButtonStyle.filled,
                      label: selected == null
                          ? 'Commencer'
                          : 'Commencer · ${controller.selectedDurationLabel}',
                      icon: Icons.play_arrow_rounded,
                      onPressed: selected == null
                          ? null
                          : controller.startSession,
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

  Widget _welcome(Color text, Color secondary) {
    final compact =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final mascotWidth = compact ? 64.0 : 108.0;
    final mascotHeight = compact ? 76.0 : 116.0;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'À ton rythme.',
                style: compact
                    ? AppTextStyles.titleMedium(
                        color: text,
                        fontWeight: FontWeight.w600,
                      )
                    : AppTextStyles.headlineSmall(
                        color: text,
                        fontWeight: FontWeight.w600,
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                compact
                    ? 'Un moment pour toi.'
                    : 'Un souffle. Une pause.\nUn moment pour toi.',
                style: compact
                    ? AppTextStyles.bodySmall(color: secondary)
                    : AppTextStyles.bodyMedium(color: secondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: mascotWidth,
          height: mascotHeight,
          child: ExcludeSemantics(
            child: MascotWithAccessories(
              config: const Mascot3DConfig(
                interactionEnabled: false,
                autoRotate: false,
                showLoadingIndicator: false,
              ),
              animation: MascotAnimations.settle,
              width: mascotWidth,
              height: mascotHeight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _durationControl(Color text, Color secondary, bool isDark) {
    final accent = isDark ? AppColors.primaryDark : AppColors.primary;
    final highContrast = MediaQuery.highContrastOf(context);
    final radius = BorderRadius.circular(24);
    return Semantics(
      button: true,
      excludeSemantics: true,
      onTap: _chooseDuration,
      label: 'Durée libre',
      value: controller.selectedDurationLabel,
      child: ElyriiGlassSurface(
        role: GlassRole.floatingControl,
        borderRadius: radius,
        glassColor: highContrast
            ? null
            : (isDark ? const Color(0xFF25282D) : Colors.white).withValues(
                alpha: isDark ? 0.30 : 0.38,
              ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('meditation-custom-duration'),
            borderRadius: radius,
            onTap: _chooseDuration,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, color: accent, size: 26),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Durée libre',
                          style: AppTextStyles.bodySmall(color: secondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          controller.selectedDurationLabel,
                          style: AppTextStyles.titleLarge(
                            color: text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.unfold_more_rounded, color: secondary, size: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _filter(String label, MeditationCategory? category, bool isDark) {
    final selected = _category == category;
    final accent = isDark ? AppColors.primaryDark : AppColors.primary;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        ElyriiHaptics.selection();
        setState(() => _category = category);
      },
      showCheckmark: false,
      labelStyle: AppTextStyles.labelMedium(
        color: selected
            ? accent
            : (isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight),
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
      backgroundColor: Colors.transparent,
      selectedColor: accent.withValues(alpha: isDark ? 0.15 : 0.10),
      side: BorderSide(
        color: selected ? accent.withValues(alpha: 0.22) : Colors.transparent,
      ),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    );
  }

  Widget _exerciseCard(
    MeditationExercise exercise,
    bool selected,
    Color text,
    Color secondary,
    bool isDark, {
    required bool compact,
  }) {
    final ink = AppColors.readableAccent(exercise.color, isDark: isDark);
    final highContrast = MediaQuery.highContrastOf(context);
    final radius = BorderRadius.circular(22);
    final icon = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: exercise.color.withValues(alpha: isDark ? 0.18 : 0.20),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(exercise.icon, color: ink, size: 22),
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
    final check = Icon(
      selected ? Icons.check_circle_rounded : Icons.circle_outlined,
      color: selected ? ink : secondary.withValues(alpha: 0.40),
      size: 20,
    );
    void selectExercise() {
      ElyriiHaptics.selection();
      controller.setExercise(exercise);
    }

    return Semantics(
      excludeSemantics: true,
      onTap: selectExercise,
      selected: selected,
      button: true,
      label: '${exercise.title}. ${exercise.subtitle}',
      child: Material(
        color: selected
            ? Color.alphaBlend(
                exercise.color.withValues(alpha: isDark ? 0.18 : 0.14),
                isDark ? const Color(0xFF262B29) : const Color(0xFFF8FAF7),
              )
            : (isDark ? const Color(0xFF262B29) : Colors.white).withValues(
                alpha: highContrast ? 1 : 0.72,
              ),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected
                ? ink.withValues(alpha: 0.55)
                : text.withValues(alpha: highContrast ? 0.4 : 0.04),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: selectExercise,
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                    constraints: const BoxConstraints(minHeight: 116),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [icon, const Spacer(), check]),
                        const SizedBox(height: 14),
                        copy,
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
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
