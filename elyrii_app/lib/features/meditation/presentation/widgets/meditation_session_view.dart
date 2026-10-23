import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/config/mascot_animations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/mascot_with_accessories.dart';
import '../../domain/models/breath_phase.dart';
import '../controllers/meditation_controller.dart';
import '../meditation_practices.dart';

class MeditationSessionView extends StatelessWidget {
  final MeditationController controller;
  final VoidCallback onExit;
  final VoidCallback onFinish;
  const MeditationSessionView({
    super.key,
    required this.controller,
    required this.onExit,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final exercise = controller.selectedExercise!;
    final type = controller.selectedBreathingType;
    final free = type == null || controller.isBreathingRecovery;
    final paused = controller.isPaused || controller.isFinished;
    final phase = paused
        ? 'À ton rythme'
        : free
        ? 'Observe'
        : meditationPhaseLabel(type.phases, controller.currentPhaseIndex);
    final count = free
        ? 'Ton souffle'
        : '${controller.phaseSecondsRemaining} s';
    final totalCycles = type == null
        ? 0
        : type == BreathingType.relaxation478
        ? 4
        : controller.selectedDurationMinutes * 60 ~/ type.cycleDuration;
    final cycle = (controller.completedCycles + 1).clamp(
      1,
      totalCycles == 0 ? 1 : totalCycles,
    );
    final remaining =
        '${controller.remainingSeconds ~/ 60}:${(controller.remainingSeconds % 60).toString().padLeft(2, '0')}';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppDimensions.maxContentWidth,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final safe = MediaQuery.paddingOf(context);
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppDimensions.radius28,
                    safe.top + AppDimensions.meditationSessionTop,
                    AppDimensions.radius28,
                    safe.bottom + AppDimensions.spacing48,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          MeditationGlassControl(
                            label: 'Fermer la séance',
                            icon: Symbols.close_rounded,
                            onPressed: onExit,
                          ),
                          const SizedBox(width: AppDimensions.spacing12),
                          Expanded(
                            child: Text(
                              MeditationPractice.forId(exercise.id)?.title ??
                                  exercise.title,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.titleSmall(
                                color: context.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacing12),
                          MeditationGlassControl(
                            label: controller.isFinished
                                ? 'Voir le résumé'
                                : paused
                                ? 'Reprendre'
                                : 'Mettre en pause',
                            icon: controller.isFinished
                                ? Symbols.check_rounded
                                : paused
                                ? Symbols.play_arrow_rounded
                                : Symbols.pause_rounded,
                            onPressed: controller.isFinished
                                ? onFinish
                                : paused
                                ? controller.resumeSession
                                : controller.pauseSession,
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDimensions.spacing32,
                        ),
                        child: Column(
                          children: [
                            MeditationBreathingCircle(controller: controller),
                            const SizedBox(
                              height: AppDimensions.meditationPhaseGap,
                            ),
                            Text(
                              phase,
                              style: AppTextStyles.headlineMedium(
                                color: context.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppDimensions.spacing8),
                            Text(
                              count,
                              style: AppTextStyles.headlineSmall(
                                color: AppColors.meditationCount(dark),
                              ),
                            ),
                            if (controller.isGuidedPractice) ...[
                              const SizedBox(height: AppDimensions.spacing20),
                              Text(
                                controller.currentGuidanceStep.title,
                                style: AppTextStyles.titleSmall(
                                  color: context.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppDimensions.spacing8),
                              Text(
                                controller.currentGuidanceStep.instruction,
                                key: const Key(
                                  'meditation-guidance-instruction',
                                ),
                                style: AppTextStyles.bodyMedium(
                                  color: context.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radius4,
                            ),
                            child: LinearProgressIndicator(
                              value: controller.progressRatio,
                              minHeight: AppDimensions.meditationProgressHeight,
                              color: AppColors.teal(dark),
                              backgroundColor: dark
                                  ? AppColors.cardDark
                                  : AppColors.cardLight,
                              semanticsLabel: 'Progression de la séance',
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacing12),
                          Text(
                            '$remaining restantes${free ? '' : ' · cycle $cycle sur $totalCycles'}',
                            style: AppTextStyles.bodySmall(
                              color: context.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppDimensions.spacing16),
                          Center(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primaryText(dark),
                                textStyle: AppTextStyles.buttonSmall(),
                                minimumSize: const Size(
                                  0,
                                  AppDimensions.meditationChipHeight,
                                ),
                              ),
                              onPressed: onFinish,
                              child: Text(
                                controller.isFinished
                                    ? 'Voir le résumé'
                                    : 'Terminer la séance',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class MeditationGlassControl extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const MeditationGlassControl({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: label,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(AppDimensions.accueilHeaderControl),
        backgroundColor: dark
            ? AppColors.glassBackgroundDark
            : AppColors.glassBackgroundLight,
        foregroundColor: context.textPrimary,
      ),
      icon: Icon(icon, fill: 1, size: AppDimensions.iconMd),
    );
  }
}

class MeditationBreathingCircle extends StatefulWidget {
  final MeditationController controller;
  const MeditationBreathingCircle({super.key, required this.controller});

  @override
  State<MeditationBreathingCircle> createState() =>
      _MeditationBreathingCircleState();
}

class _MeditationBreathingCircleState extends State<MeditationBreathingCircle>
    with SingleTickerProviderStateMixin {
  late final _breath = AnimationController(vsync: this);
  int? _phase;
  bool? _running;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced != reduced) {
      _reduced = reduced;
      _phase = null;
    }
    _sync();
  }

  @override
  void didUpdateWidget(MeditationBreathingCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
      _phase = null;
      _running = null;
      _sync();
    }
  }

  void _sync() {
    final controller = widget.controller;
    final type = controller.selectedBreathingType;
    if (type == null ||
        controller.isBreathingRecovery ||
        _reduced ||
        controller.isSetup) {
      _breath.stop();
      _breath.value = .5;
      return;
    }
    final changed = _phase != controller.currentPhaseIndex;
    if (!changed && _running == controller.isRunning) return;
    _phase = controller.currentPhaseIndex;
    _running = controller.isRunning;
    _breath.stop();
    final phase = controller.currentPhase;
    if (changed) {
      final elapsed = 1 - controller.phaseSecondsRemaining / phase.seconds;
      _breath.value = switch (phase.action) {
        BreathAction.expand => elapsed,
        BreathAction.contract => 1 - elapsed,
        BreathAction.hold =>
          type
                      .phases[(controller.currentPhaseIndex - 1) %
                          type.phases.length]
                      .action ==
                  BreathAction.expand
              ? 1
              : 0,
      };
    }
    if (!controller.isRunning || phase.action == BreathAction.hold) return;
    final expanding = phase.action == BreathAction.expand;
    final remainingFraction = expanding ? 1 - _breath.value : _breath.value;
    _breath.animateTo(
      expanding ? 1 : 0,
      duration: Duration(
        microseconds:
            (phase.seconds * Duration.microsecondsPerSecond * remainingFraction)
                .round(),
      ),
      curve: Curves.linear,
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final natural =
        widget.controller.isGuidedPractice ||
        widget.controller.isBreathingRecovery;
    return SizedBox.square(
      dimension: AppDimensions.meditationCircle,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _breath,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.tealDark.withValues(alpha: .2),
              ),
              child: const SizedBox.expand(),
            ),
            builder: (_, child) => Transform.scale(
              scale: _reduced || natural
                  ? 1
                  : AppDimensions.meditationCircleMinScale +
                        (1 - AppDimensions.meditationCircleMinScale) *
                            AppMotion.meditationBreath.transform(_breath.value),
              child: child,
            ),
          ),
          Positioned(
            left:
                (AppDimensions.meditationCircle -
                    AppDimensions.meditationMascotWidth) /
                2,
            top:
                (AppDimensions.meditationCircle -
                    AppDimensions.meditationMascotHeight) /
                2,
            width: AppDimensions.meditationMascotWidth,
            height: AppDimensions.meditationMascotHeight,
            child: Semantics(
              label: 'Elyrii avec ta tenue',
              image: true,
              child: MascotWithAccessories(
                config: const Mascot3DConfig(
                  interactionEnabled: false,
                  autoRotate: false,
                ),
                width: AppDimensions.meditationMascotWidth,
                height: AppDimensions.meditationMascotHeight,
                animation: natural
                    ? MascotAnimations.idle
                    : MascotAnimations.breathe,
                breathProgress: natural ? null : _breath,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
