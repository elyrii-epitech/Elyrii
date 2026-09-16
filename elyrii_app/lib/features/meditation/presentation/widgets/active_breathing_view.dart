import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_button.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';
import '../../../../core/widgets/mascot_with_accessories.dart';
import '../../../../core/config/mascot_animations.dart';
import '../../domain/models/breath_phase.dart';
import '../controllers/meditation_controller.dart';

/// Vue de respiration active plein écran : cercle zen, timer discret et contrôles.
class ActiveBreathingView extends StatefulWidget {
  final MeditationController controller;

  const ActiveBreathingView({super.key, required this.controller});

  @override
  State<ActiveBreathingView> createState() => _ActiveBreathingViewState();
}

class _ActiveBreathingViewState extends State<ActiveBreathingView>
    with TickerProviderStateMixin {
  late AnimationController _breathScaleController;
  late Animation<double> _breathScale;
  int _lastPhaseIndex = -1;
  bool _lastPaused = false;

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
      _syncAnimationWithPhase();
    }
  }

  void _onControllerTick() {
    if (!mounted) return;
    if (widget.controller.currentPhaseIndex != _lastPhaseIndex) {
      _syncAnimationWithPhase();
    }
    // Repeint la mascotte : boucle breathe ↔ pose tenue en pause.
    if (widget.controller.isPaused != _lastPaused) {
      _lastPaused = widget.controller.isPaused;
      setState(() {});
    }
  }

  void _syncAnimationWithPhase() {
    final phase = widget.controller.currentPhase;
    _lastPhaseIndex = widget.controller.currentPhaseIndex;
    final duration = Duration(seconds: phase.seconds);

    _breathScaleController.duration = duration;

    switch (phase.action) {
      case BreathAction.expand:
        _breathScaleController.forward(from: 0.0);
        break;
      case BreathAction.contract:
        _breathScaleController.reverse(from: 1.0);
        break;
      case BreathAction.hold:
        _breathScaleController.stop();
        break;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerTick);
    _breathScaleController.dispose();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _confirmStopSession(BuildContext context) {
    widget.controller.pauseSession();
    showCupertinoModalPopup<bool>(
      context: context,
      builder: (modalContext) => CupertinoActionSheet(
        title: const Text('Quitter la séance ?'),
        message: const Text(
          'La séance en cours sera interrompue et non comptabilisée.',
        ),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(modalContext, true);
            widget.controller.resumeSession();
          },
          child: const Text('Reprendre la séance'),
        ),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(modalContext, false);
              widget.controller.stopSession(finished: false);
            },
            child: const Text('Interrompre'),
          ),
        ],
      ),
    ).then((result) {
      // Rejet hors boutons (tap à l'extérieur) : la séance reprend.
      if (result == null && widget.controller.isPaused) {
        widget.controller.resumeSession();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtitleColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final currentPhase = widget.controller.currentPhase;
    final isPaused = widget.controller.isPaused;
    final accent = widget.controller.selectedBreathingType.color;

    return Column(
      children: [
        // ---- En-tête : badge technique + bouton quitter ----
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.pageHorizontalPadding,
            vertical: AppDimensions.spacingSm,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(currentPhase.icon, size: 14, color: accent),
                    const SizedBox(width: 6),
                    Text(
                      widget.controller.selectedBreathingType.label,
                      style: AppTextStyles.labelMedium(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              LiquidGlassIconButton(
                icon: Icons.close_rounded,
                size: 40,
                color: subtitleColor,
                onPressed: () => _confirmStopSession(context),
              ),
            ],
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
              final orbSize = (constraints.maxWidth * 0.72).clamp(220.0, 300.0);
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 1),
                  _buildBreathingOrb(isDark, accent, orbSize),
                  const SizedBox(height: AppDimensions.spacingLg),
                  Text(
                    isPaused ? 'En pause' : currentPhase.label,
                    style: AppTextStyles.headlineMedium(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.controller.phaseSecondsRemaining} s',
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
                color: accent,
              ),
              _buildStatPill(
                isDark,
                icon: Icons.timer_outlined,
                value: _formatTime(widget.controller.remainingSeconds),
                label: 'restant',
                color: AppColors.primary,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppDimensions.spacingLg),

        // Contrôles d'action (Stop + Play/Pause)
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingXl,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LiquidGlassIconButton(
                icon: Icons.stop_rounded,
                onPressed: () => _confirmStopSession(context),
                size: 56,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
              const SizedBox(width: AppDimensions.spacingLg),
              LiquidGlassCard(
                onTap: isPaused
                    ? widget.controller.resumeSession
                    : widget.controller.pauseSession,
                borderRadius: 40,
                padding: const EdgeInsets.all(20),
                color: accent.withValues(alpha: 0.22),
                borderColor: accent.withValues(alpha: 0.5),
                child: Icon(
                  isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  size: 36,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 90),
      ],
    );
  }

  Widget _buildBreathingOrb(bool isDark, Color accent, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Champ de respiration éthéré façon Apple Watch Breathe : aucun
          // anneau ni bordure rigide, deux voiles de lumière qui respirent
          // en phase avec l'exercice.
          AnimatedBuilder(
            animation: _breathScale,
            builder: (context, _) {
              // Progression normalisée de la phase (0 = contracté, 1 = étendu).
              final t = (_breathScale.value - 0.82) / 0.36;
              final intensity = 0.55 + 0.45 * t;

              return Stack(
                alignment: Alignment.center,
                children: [
                  // Halo ambiant externe.
                  Transform.scale(
                    scale: 0.94 + t * 0.12,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            accent.withValues(
                              alpha: (isDark ? 0.20 : 0.14) * intensity,
                            ),
                            accent.withValues(
                              alpha: (isDark ? 0.08 : 0.06) * intensity,
                            ),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.55, 1.0],
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

          // Mascotte centrale : sa propre respiration (clip `breathe`)
          // accompagne le rythme de l'exercice.
          MascotWithAccessories(
            config: const Mascot3DConfig(
              interactionEnabled: false,
              autoRotate: false,
            ),
            // Boucle de respiration pendant la séance ; la pause fige
            // la pose exacte (MascotAnimationMode.hold).
            animation: widget.controller.isPaused
                ? MascotAnimations.holdPose
                : MascotAnimations.breathe,
            width: 140,
            height: 140,
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
