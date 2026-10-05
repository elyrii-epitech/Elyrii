import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_button.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';
import '../../../../core/widgets/mascot_with_accessories.dart';
import '../../../../core/widgets/elyrii_page_header.dart';
import '../../../../core/config/mascot_animations.dart';
import '../../domain/models/breath_phase.dart';
import '../controllers/meditation_controller.dart';

/// Vue de respiration active plein écran : cercle zen, timer discret et contrôles.
///
/// L'hôte ([MeditationSessionPage]) fournit [onRequestExit] pour demander une
/// sortie confirmée : cette vue ne gère plus elle-même la boîte de dialogue.
class ActiveBreathingView extends StatefulWidget {
  final MeditationController controller;
  final VoidCallback onRequestExit;

  const ActiveBreathingView({
    super.key,
    required this.controller,
    required this.onRequestExit,
  });

  @override
  State<ActiveBreathingView> createState() => _ActiveBreathingViewState();
}

class _ActiveBreathingViewState extends State<ActiveBreathingView>
    with TickerProviderStateMixin {
  late AnimationController _breathScaleController;
  late Animation<double> _breathScale;
  int _lastPhaseIndex = -1;
  bool _lastPaused = false;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();

    _breathScaleController = AnimationController(vsync: this);
    _breathScale = Tween<double>(begin: 0.82, end: 1.18).animate(
      CurvedAnimation(
        parent: _breathScaleController,
        curve: Curves.easeInOutSine,
      ),
    );

    widget.controller.addListener(_onControllerTick);
    _syncAnimationWithPhase();
  }

  @override
  void didUpdateWidget(ActiveBreathingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerTick);
      widget.controller.addListener(_onControllerTick);
      _lastPhaseIndex = -1;
      _syncAnimationWithPhase();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion != reduced) {
      _reducedMotion = reduced;
      _lastPhaseIndex = -1;
      _syncAnimationWithPhase();
    }
  }

  void _onControllerTick() {
    if (!mounted) return;
    if (widget.controller.currentPhaseIndex != _lastPhaseIndex ||
        widget.controller.isPaused != _lastPaused) {
      _syncAnimationWithPhase();
    }
  }

  void _syncAnimationWithPhase() {
    final controller = widget.controller;
    final phase = controller.currentPhase;
    final changed = _lastPhaseIndex != controller.currentPhaseIndex;
    _lastPhaseIndex = controller.currentPhaseIndex;
    _lastPaused = controller.isPaused;
    _breathScaleController.stop();
    if (_reducedMotion || controller.isBreathingRecovery) {
      _breathScaleController.value = .5;
      return;
    }
    if (changed) {
      final elapsed = (1 - controller.phaseSecondsRemaining / phase.seconds)
          .clamp(0.0, 1.0);
      switch (phase.action) {
        case BreathAction.expand:
          _breathScaleController.value = elapsed;
        case BreathAction.contract:
          _breathScaleController.value = 1 - elapsed;
        case BreathAction.hold:
          // Retrouve aussi la bonne pose en arrivant au milieu d'une rétention.
          final phases = controller.selectedBreathingType!.phases;
          final previous =
              phases[(controller.currentPhaseIndex - 1) % phases.length];
          _breathScaleController.value = previous.action == BreathAction.expand
              ? 1
              : 0;
      }
    }
    if (controller.isPaused || phase.action == BreathAction.hold) return;
    final target = phase.action == BreathAction.expand ? 1.0 : 0.0;
    _breathScaleController.animateTo(
      target,
      // La reprise part de la pose exacte et rejoint la prochaine transition
      // du minuteur, même si la pause a eu lieu au milieu d'une seconde.
      duration: Duration(seconds: controller.phaseSecondsRemaining),
      curve: Curves.linear,
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerTick);
    _breathScaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtitleColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final currentPhase = widget.controller.currentPhase;
    final isPaused = widget.controller.isPaused;
    final accent = widget.controller.selectedBreathingType!.color;
    final ink = AppColors.readableAccent(accent, isDark: isDark);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: ElyriiPageHeader(
            title: widget.controller.selectedExercise!.title,
            subtitle: 'Respiration guidée',
            leading: Semantics(
              label: 'Interrompre la séance',
              button: true,
              child: LiquidGlassIconButton(
                icon: Icons.close_rounded,
                onPressed: widget.onRequestExit,
                size: 44,
              ),
            ),
            trailing: Semantics(
              label: isPaused ? 'Reprendre la séance' : 'Mettre en pause',
              button: true,
              child: LiquidGlassIconButton(
                icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                onPressed: isPaused
                    ? widget.controller.resumeSession
                    : widget.controller.pauseSession,
                color: ink,
                size: 44,
              ),
            ),
          ),
        ),

        // Barre de progression globale
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.pageHorizontalPadding,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: widget.controller.progressRatio,
              minHeight: 5,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ),

        // Corps principal : Cercle de respiration centré
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scaler = MediaQuery.textScalerOf(context);
              final labelsHeight =
                  scaler.scale(28) * 1.29 + scaler.scale(16) * 1.5 + 34;
              final orbSize = math.max(
                0.0,
                math.min(
                  math.min(constraints.maxWidth * 0.8, 340.0),
                  constraints.maxHeight - labelsHeight,
                ),
              );
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 1),
                  _buildBreathingOrb(isDark, accent, orbSize),
                  const SizedBox(height: AppDimensions.spacingLg),
                  Text(
                    isPaused ? 'En pause' : currentPhase.label,
                    style: AppTextStyles.headlineMedium(
                      color: ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.controller.isBreathingRecovery
                        ? 'À ton rythme'
                        : '${widget.controller.phaseSecondsRemaining} s',
                    style: AppTextStyles.titleMedium(color: subtitleColor),
                  ),
                  const Spacer(flex: 1),
                ],
              );
            },
          ),
        ),

        // Compteur de cycles + temps restant
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.pageHorizontalPadding,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatPill(
                isDark,
                icon: Icons.refresh_rounded,
                value: '${widget.controller.completedCycles}',
                label: 'cycles',
                color: ink,
              ),
              _buildStatPill(
                isDark,
                icon: Icons.timer_outlined,
                value: widget.controller.formattedRemainingTime,
                label: 'restant',
                color: isDark ? AppColors.primaryDark : AppColors.primary,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppDimensions.spacingLg),

        SizedBox(height: MediaQuery.of(context).padding.bottom + 28),
      ],
    );
  }

  Widget _buildBreathingOrb(bool isDark, Color accent, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _breathScale,
            builder: (context, _) {
              // Halo lumineux externe dont l'intensité respire avec le souffle.
              final intensity = Curves.easeInOut.transform(
                _breathScale.value.clamp(0.0, 1.0),
              );
              return Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: _breathScale.value,
                    child: Container(
                      width: size * 0.92,
                      height: size * 0.92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            accent.withValues(
                              alpha: (isDark ? 0.20 : 0.14) * intensity,
                            ),
                            accent.withValues(
                              alpha: (isDark ? 0.08 : 0.05) * intensity,
                            ),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.7, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Cercle de guidage interne, souffle doux sans liseré dur.
                  Transform.scale(
                    scale: _breathScale.value,
                    child: Container(
                      width: size * 0.72,
                      height: size * 0.72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            accent.withValues(
                              alpha: (isDark ? 0.26 : 0.18) * intensity,
                            ),
                            accent.withValues(
                              alpha: (isDark ? 0.12 : 0.08) * intensity,
                            ),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.7, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // La mascotte et le cercle partagent la même progression, pauses incluses.
          MascotWithAccessories(
            config: const Mascot3DConfig(
              interactionEnabled: false,
              autoRotate: false,
            ),
            animation: MascotAnimations.breathe,
            breathProgress: _breathScaleController,
            width: size * 0.52,
            height: size * 0.52,
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(
    bool isDark, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return LiquidGlassCard(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTextStyles.titleSmall(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: AppTextStyles.labelSmall(
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
