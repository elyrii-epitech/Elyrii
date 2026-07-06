import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/glass/liquid_glass_button.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';
import '../../../../core/widgets/mascot_with_accessories.dart';
import '../../data/repositories/meditation_repository.dart';

/// Action de respiration appliquée à une phase.
enum BreathAction { expand, hold, contract }

/// Définition d'une phase de respiration.
class BreathPhase {
  const BreathPhase(this.seconds, this.label, this.action);
  final int seconds;
  final String label;
  final BreathAction action;

  /// Icône pertinente selon l'action de la phase.
  IconData get icon {
    switch (action) {
      case BreathAction.expand:
        return Icons.arrow_outward_rounded;
      case BreathAction.contract:
        return Icons.arrow_downward_rounded;
      case BreathAction.hold:
        return Icons.pause_rounded;
    }
  }
}

/// Breathing exercise types available in the meditation page.
///
/// Chaque technique est reconnue dans le domaine du bien-être et de la
/// psychologie physiologique. Les durées sont exprimées en secondes.
enum BreathingType {
  /// 4-7-8 breathing (Dr. Andrew Weil) : inspire 4s, retiens 7s, expire 8s.
  relaxation478(
    'Respiration 4-7-8',
    [
      BreathPhase(4, 'Inspire', BreathAction.expand),
      BreathPhase(7, 'Retiens', BreathAction.hold),
      BreathPhase(8, 'Expire', BreathAction.contract),
    ],
    'Apaisante et profonde, idéale avant le sommeil.',
    'Dr. Andrew Weil',
    Icons.nights_stay_rounded,
    Color(0xFF7E6AD8),
  ),

  /// Box breathing (Navy SEALs) : 4-4-4-4.
  carree(
    'Respiration carrée',
    [
      BreathPhase(4, 'Inspire', BreathAction.expand),
      BreathPhase(4, 'Retiens', BreathAction.hold),
      BreathPhase(4, 'Expire', BreathAction.contract),
      BreathPhase(4, 'Retiens', BreathAction.hold),
    ],
    'Équilibrante, utilisée pour la concentration.',
    'Navy SEALs',
    Icons.crop_square_rounded,
    Color(0xFFA8D5BA),
  ),

  /// Cohérence cardiaque : 5-5, respire au rythme de 6/min.
  coherence(
    'Cohérence cardiaque',
    [
      BreathPhase(5, 'Inspire', BreathAction.expand),
      BreathPhase(5, 'Expire', BreathAction.contract),
    ],
    'Équilibre le système nerveux et le rythme cardiaque.',
    '5 bpm · David Servan-Schreiber',
    Icons.favorite_rounded,
    Color(0xFFFFB5A8),
  ),

  /// Respiration diaphragmatique (ventrale) : 4-2-6.
  diaphragmatique(
    'Respiration diaphragmatique',
    [
      BreathPhase(4, 'Inspire', BreathAction.expand),
      BreathPhase(2, 'Retiens', BreathAction.hold),
      BreathPhase(6, 'Expire', BreathAction.contract),
    ],
    'Ventrale et relaxante, détend le dos et le ventre.',
    'Respiration profonde du ventre',
    Icons.air_rounded,
    Color(0xFF93B8DA),
  ),

  /// Ujjayi (respiration océanique du yoga / pranayama) : 6-6.
  ujjayi(
    'Respiration Ujjayi',
    [
      BreathPhase(6, 'Inspire', BreathAction.expand),
      BreathPhase(6, 'Expire', BreathAction.contract),
    ],
    'Respiration océanique du yoga, ancre et réchauffe.',
    'Pranayama · Yoga',
    Icons.waves_rounded,
    Color(0xFFFDD876),
  );

  const BreathingType(
    this.label,
    this.phases,
    this.description,
    this.origin,
    this.icon,
    this.color,
  );

  /// French display label.
  final String label;

  /// Phases successives (durée + libellé + action de respiration).
  final List<BreathPhase> phases;

  /// Short French description.
  final String description;

  /// Origine ou cadre de la technique (badge).
  final String origin;

  /// Icône représentative.
  final IconData icon;

  /// Couleur d'accent de la technique.
  final Color color;

  /// Durée totale d'un cycle complet en secondes.
  int get cycleDuration => phases.fold(0, (prev, p) => prev + p.seconds);
}

/// Overall state of the meditation session.
enum _SessionState {
  /// Choosing settings before starting.
  setup,

  /// Actively running a breathing exercise.
  running,

  /// Exercise is paused mid-session.
  paused,

  /// Session completed – showing mood picker.
  finished,
}

class MeditationPage extends StatefulWidget {
  const MeditationPage({super.key});

  @override
  State<MeditationPage> createState() => _MeditationPageState();
}

class _MeditationPageState extends State<MeditationPage>
    with TickerProviderStateMixin {
  // ---- User selections ----
  int _selectedDurationMinutes = 5;
  BreathingType _selectedBreathingType = BreathingType.relaxation478;

  // ---- Session state ----
  _SessionState _sessionState = _SessionState.setup;
  late int _remainingSeconds;
  int _currentPhaseIndex = 0;
  int _phaseSecondsRemaining = 0;
  int _completedCycles = 0;

  // ---- Animation ----
  late AnimationController _breathScaleController;
  late Animation<double> _breathScale;
  late AnimationController _glowController;
  late AnimationController _phaseRingController;

  /// Timer driving the breathing countdown.
  Timer? _timer;
  MeditationRepository? _repository;
  String? _backendSessionId;
  String? _backendError;
  bool _isStartingSession = false;
  bool _hasCompletedBackend = false;

  /// Whether the post-session mood has been picked.
  int? _selectedMood;

  // ---- Available durations (minutes) ----
  static const List<int> _durations = [5, 10, 15];

  // ---- Mood emoji list for post-session feedback ----
  static const List<_MoodOption> _moods = [
    _MoodOption(
      Icons.sentiment_very_dissatisfied_rounded,
      'Pas bien',
      'verySad',
      Color(0xFF7BA3C7),
    ),
    _MoodOption(
      Icons.sentiment_neutral_rounded,
      'Neutre',
      'neutral',
      Color(0xFFA39C96),
    ),
    _MoodOption(
      Icons.sentiment_satisfied_rounded,
      'Bien',
      'happy',
      Color(0xFFA8D5BA),
    ),
    _MoodOption(
      Icons.sentiment_satisfied_alt_rounded,
      'Apaisé(e)',
      'happy',
      Color(0xFF7BC393),
    ),
    _MoodOption(
      Icons.sentiment_very_satisfied_rounded,
      'Merveilleux',
      'veryHappy',
      Color(0xFF5FA87A),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _remainingSeconds = _selectedDurationMinutes * 60;

    // Scale animation for the breathing circle (0 = contracted, 1 = expanded).
    // Duration is set dynamically per phase for perfect sync.
    _breathScaleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _breathScale = CurvedAnimation(
      parent: _breathScaleController,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );

    // Subtle pulsing glow that loops.
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    // Smooth progress ring sweeping within a phase (always 0->1).
    _phaseRingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repository ??= MeditationRepository(client: context.read<ApiClient>());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _breathScaleController.dispose();
    _glowController.dispose();
    _phaseRingController.dispose();
    super.dispose();
  }

  // ============================================================
  // Session control
  // ============================================================

  Future<void> _startSession() async {
    if (_isStartingSession) return;

    setState(() {
      _isStartingSession = true;
      _backendError = null;
    });

    try {
      final session = await _repository!.startSession(
        type: _programIdForDuration(_selectedDurationMinutes),
        durationMinutes: _selectedDurationMinutes,
      );

      setState(() {
        _backendSessionId = session.id;
        _hasCompletedBackend = false;
        _sessionState = _SessionState.running;
        _remainingSeconds = _selectedDurationMinutes * 60;
        _currentPhaseIndex = 0;
        _completedCycles = 0;
        _phaseSecondsRemaining = _selectedBreathingType.phases.first.seconds;
        _selectedMood = null;
      });

      // Start with inhale -> expand.
      _applyPhaseAction(_selectedBreathingType.phases.first);

      _startTimer();
    } catch (e) {
      setState(() {
        _backendError = 'Impossible de démarrer la session: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isStartingSession = false);
      }
    }
  }

  void _pauseSession() {
    _timer?.cancel();
    _breathScaleController.stop();
    _phaseRingController.stop();
    setState(() => _sessionState = _SessionState.paused);
  }

  void _resumeSession() {
    final phase = _selectedBreathingType.phases[_currentPhaseIndex];
    final remaining = Duration(seconds: _phaseSecondsRemaining);
    _breathScaleController.duration = remaining;
    _phaseRingController.duration = remaining;

    switch (phase.action) {
      case BreathAction.expand:
        _breathScaleController.forward();
      case BreathAction.contract:
        _breathScaleController.reverse();
      case BreathAction.hold:
        break;
    }
    _phaseRingController.forward();

    setState(() => _sessionState = _SessionState.running);
    _startTimer();
  }

  Future<void> _stopSession({bool finished = false}) async {
    _timer?.cancel();
    _breathScaleController.reverse();
    final shouldCancel =
        !finished &&
        _sessionState != _SessionState.finished &&
        _backendSessionId != null;
    final sessionId = _backendSessionId;

    if (shouldCancel && sessionId != null) {
      try {
        await _repository!.cancelSession(sessionId);
      } catch (e) {
        _backendError = 'Impossible d\'annuler la session: $e';
      }
    }

    setState(() {
      _sessionState = finished ? _SessionState.finished : _SessionState.setup;
      if (!finished) _remainingSeconds = _selectedDurationMinutes * 60;
      if (!finished) _backendSessionId = null;
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _timer?.cancel();
        return;
      }

      setState(() {
        // Global countdown.
        _remainingSeconds--;

        // Phase countdown.
        _phaseSecondsRemaining--;

        if (_phaseSecondsRemaining <= 0) {
          _advancePhase();
        }

        // Session complete.
        if (_remainingSeconds <= 0) {
          _timer?.cancel();
          _breathScaleController.reverse();
          _sessionState = _SessionState.finished;
          unawaited(_completeBackendSession());
        }
      });
    });
  }

  Future<void> _completeBackendSession({String? moodAfter}) async {
    final sessionId = _backendSessionId;
    if (sessionId == null) return;
    if (_hasCompletedBackend && moodAfter == null) return;

    try {
      await _repository!.completeSession(
        sessionId: sessionId,
        moodAfter: moodAfter,
      );
      _hasCompletedBackend = true;
      if (mounted) {
        setState(() => _backendError = null);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _backendError = 'Impossible d\'enregistrer la méditation: $e';
        });
      }
    }
  }

  String _programIdForDuration(int durationMinutes) {
    switch (durationMinutes) {
      case 10:
        return 'body-scan-10m';
      case 15:
        return 'grounding-15m';
      case 5:
      default:
        return 'breathing-5m';
    }
  }

  void _advancePhase() {
    final phases = _selectedBreathingType.phases;
    final nextIndex = (_currentPhaseIndex + 1) % phases.length;

    // Un cycle complet est compté quand on revient à la première phase.
    if (nextIndex == 0) {
      _completedCycles++;
    }

    _currentPhaseIndex = nextIndex;
    final phase = phases[_currentPhaseIndex];
    _phaseSecondsRemaining = phase.seconds;
    _applyPhaseAction(phase);
  }

  /// Pilote la direction du cercle (et donc de la mascotte) selon l'action.
  /// La duree de l'animation est synchronisee avec la duree de la phase.
  void _applyPhaseAction(BreathPhase phase) {
    final duration = Duration(seconds: phase.seconds);
    _breathScaleController.duration = duration;
    _phaseRingController.duration = duration;

    // L'anneau de progression repart toujours de 0.
    _phaseRingController.forward(from: 0.0);

    switch (phase.action) {
      case BreathAction.expand:
        _breathScaleController.forward();
      case BreathAction.contract:
        _breathScaleController.reverse();
      case BreathAction.hold:
        // Garde la position actuelle (pleine ou vide).
        break;
    }
  }

  /// Format [seconds] as MM:SS.
  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Ratio d'avancement global de la session (0..1).
  double get _sessionProgress {
    final total = _selectedDurationMinutes * 60;
    if (total <= 0) return 0;
    return (total - _remainingSeconds) / total;
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.scaffoldDark
          : AppColors.scaffoldLight,
      body: SafeArea(bottom: false, child: _buildBody(isDark)),
    );
  }

  /// Chooses which body to display depending on [_sessionState].
  Widget _buildBody(bool isDark) {
    switch (_sessionState) {
      case _SessionState.setup:
        return _buildSetupView(isDark);
      case _SessionState.running:
      case _SessionState.paused:
        return _buildExerciseView(isDark);
      case _SessionState.finished:
        return _buildFinishedView(isDark);
    }
  }

  // ============================================================
  // Setup view – duration & breathing type pickers
  // ============================================================

  Widget _buildSetupView(bool isDark) {
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final subtitleColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: AppDimensions.spacingSm),
              _buildMascotHero(isDark, textColor, subtitleColor),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.pageHorizontalPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_backendError != null) ...[
                  const SizedBox(height: AppDimensions.spacingMd),
                  _buildSyncError(isDark),
                ],
                const SizedBox(height: AppDimensions.spacingLg),

                // Duration selector.
                _buildSectionLabel(
                  isDark,
                  'Durée de la session',
                  Icons.timer_outlined,
                  textColor,
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                _buildDurationChips(isDark),

                const SizedBox(height: AppDimensions.spacingXl),

                // Breathing type selector.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionLabel(
                      isDark,
                      'Technique de respiration',
                      Icons.air_rounded,
                      textColor,
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                _buildBreathingTypeCards(isDark, textColor, subtitleColor),

                const SizedBox(height: AppDimensions.spacingXxl),

                // Start button.
                Center(child: _buildStartButton(isDark)),

                const SizedBox(height: AppDimensions.spacingXxl),
                // Espace pour la navbar flottante.
                SizedBox(height: MediaQuery.of(context).padding.bottom + 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Héros : mascotte 3D dans un halo lumineux + titre.
  Widget _buildMascotHero(bool isDark, Color textColor, Color subtitleColor) {
    return Column(
      children: [
        SizedBox(
              width: 200,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Halo pulsant.
                  AnimatedBuilder(
                    animation: _glowController,
                    builder: (context, _) {
                      return Transform.scale(
                        scale: 1.0 + (_glowController.value * 0.08),
                        child: Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.primary.withValues(alpha: 0.18),
                                AppColors.secondary.withValues(alpha: 0.08),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.55, 1.0],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Mascotte 3D.
                  const MascotWithAccessories(
                    config: Mascot3DConfig(
                      autoRotate: false,
                      interactionEnabled: false,
                      showLoadingIndicator: false,
                    ),
                    width: 170,
                    height: 180,
                  ),
                ],
              ),
            )
            .animate()
            .fadeIn(duration: 700.ms)
            .slideY(begin: -0.12, end: 0, duration: 700.ms),
        const SizedBox(height: AppDimensions.spacingXs),
        Text(
          'Respire',
          style: AppTextStyles.headlineLarge(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 150.ms),
        const SizedBox(height: 4),
        Text(
          'Prends un moment pour toi',
          style: AppTextStyles.bodyMedium(color: subtitleColor),
        ).animate().fadeIn(duration: 600.ms, delay: 250.ms),
        const SizedBox(height: AppDimensions.spacingXxs),
        Text(
          _greetingForTime(),
          style: AppTextStyles.labelMedium(
            color: subtitleColor.withValues(alpha: 0.85),
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(duration: 600.ms, delay: 350.ms),
      ],
    );
  }

  /// Petit message de salutation adapté à l'heure de la journée.
  String _greetingForTime() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Le matin se prête aux respirations énergisantes.';
    } else if (hour >= 12 && hour < 18) {
      return 'Fais une pause et reconnecte-toi à ton souffle.';
    } else if (hour >= 18 && hour < 22) {
      return 'Le soir, laisse le jour s\'apaiser doucement.';
    } else {
      return 'Quelques respirations pour retrouver le calme.';
    }
  }

  Widget _buildSectionLabel(
    bool isDark,
    String text,
    IconData icon,
    Color textColor,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          text,
          style: AppTextStyles.titleMedium(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDurationChips(bool isDark) {
    return Wrap(
      spacing: AppDimensions.spacingSm,
      runSpacing: AppDimensions.spacingSm,
      children: _durations.map((d) {
        final selected = d == _selectedDurationMinutes;
        return LiquidGlassCard(
          onTap: () => setState(() => _selectedDurationMinutes = d),
          borderRadius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          color: selected
              ? AppColors.primary.withValues(alpha: 0.22)
              : (isDark
                    ? AppColors.liquidGlassBackgroundDark
                    : AppColors.liquidGlassBackgroundLight),
          borderColor: selected
              ? AppColors.primary.withValues(alpha: 0.55)
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : Icons.schedule_rounded,
                size: 16,
                color: selected
                    ? AppColors.primary
                    : (isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight),
              ),
              const SizedBox(width: 6),
              Text(
                '$d min',
                style: AppTextStyles.labelMedium(
                  color: selected
                      ? AppColors.primary
                      : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBreathingTypeCards(
    bool isDark,
    Color textColor,
    Color subtitleColor,
  ) {
    return Column(
      children: BreathingType.values.map((type) {
        final selected = type == _selectedBreathingType;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
          child: LiquidGlassCard(
            onTap: () => setState(() => _selectedBreathingType = type),
            borderRadius: AppDimensions.radiusLiquidGlassCard,
            padding: const EdgeInsets.all(AppDimensions.paddingMd),
            color: selected
                ? type.color.withValues(alpha: isDark ? 0.18 : 0.14)
                : (isDark
                      ? AppColors.liquidGlassBackgroundDark
                      : AppColors.liquidGlassBackgroundLight),
            borderColor: selected ? type.color.withValues(alpha: 0.55) : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icône / cercle d'accent.
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        type.color.withValues(alpha: 0.35),
                        type.color.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.7, 1.0],
                    ),
                    border: Border.all(
                      color: type.color.withValues(
                        alpha: selected ? 0.6 : 0.25,
                      ),
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Icon(type.icon, size: 22, color: type.color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              type.label,
                              style: AppTextStyles.titleSmall(
                                color: selected ? type.color : textColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (selected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: type.color,
                              size: 20,
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        type.description,
                        style: AppTextStyles.bodySmall(color: subtitleColor),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // Badge origine.
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: type.color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: type.color.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              type.origin,
                              style: AppTextStyles.labelSmall(
                                color: type.color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Mini pattern viz.
                          Expanded(child: _buildPatternDots(type)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Visualisation abstraite du pattern de respiration (points proportionnels).
  Widget _buildPatternDots(BreathingType type) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: type.phases.asMap().entries.map((entry) {
        final phase = entry.value;
        final isActive =
            type == _selectedBreathingType &&
            _sessionState != _SessionState.setup &&
            entry.key == _currentPhaseIndex;
        final size = 6.0 + (phase.seconds / 8.0 * 8).clamp(0.0, 8.0);
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: phase.action == BreathAction.contract
                  ? type.color.withValues(alpha: isActive ? 0.9 : 0.4)
                  : type.color.withValues(alpha: isActive ? 0.8 : 0.3),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStartButton(bool isDark) {
    return LiquidGlassCard(
      onTap: _isStartingSession ? null : _startSession,
      borderRadius: 30,
      padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 18),
      color: AppColors.primary.withValues(alpha: 0.22),
      borderColor: AppColors.primary.withValues(alpha: 0.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isStartingSession ? Icons.sync_rounded : Icons.play_arrow_rounded,
            color: AppColors.primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            _isStartingSession ? 'Connexion...' : 'Commencer la session',
            style: AppTextStyles.labelLarge(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: 0.2, end: 0, delay: 300.ms).fadeIn();
  }

  Widget _buildSyncError(bool isDark) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _backendError!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Exercise view – mascot breathing in sync + animated circle
  // ============================================================

  Widget _buildExerciseView(bool isDark) {
    final subtitleColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    final currentPhase = _selectedBreathingType.phases[_currentPhaseIndex];
    final isPaused = _sessionState == _SessionState.paused;
    final accent = _selectedBreathingType.color;

    return Column(
      children: [
        // ---- Header : type + minuteur global ----
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.pageHorizontalPadding,
            vertical: AppDimensions.spacingSm,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
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
                      _selectedBreathingType.label,
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
                onPressed: () => _stopSession(),
              ),
            ],
          ),
        ),

        // Barre de progression globale.
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.pageHorizontalPadding,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _sessionProgress.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ),

        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final orbSize = (constraints.maxWidth * 0.75).clamp(220.0, 300.0);
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 1),

                  // ---- Cercle de respiration + mascotte ----
                  _buildBreathingOrb(isDark, accent, orbSize),

                  const SizedBox(height: AppDimensions.spacingLg),

                  // Phase text + countdown.
                  Text(
                    isPaused ? 'Pause' : currentPhase.label,
                    style: AppTextStyles.headlineMedium(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_phaseSecondsRemaining s',
                    style: AppTextStyles.titleMedium(color: subtitleColor),
                  ),

                  const Spacer(flex: 1),
                ],
              );
            },
          ),
        ),

        // ---- Compteur de cycles + minuteur ----
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
                value: '$_completedCycles',
                label: 'cycles',
                color: accent,
              ),
              _buildStatPill(
                isDark,
                icon: Icons.timer_outlined,
                value: _formatTime(_remainingSeconds),
                label: 'restant',
                color: AppColors.primary,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppDimensions.spacingLg),

        // ---- Controls ----
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingXl,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Stop button.
              LiquidGlassIconButton(
                icon: Icons.stop_rounded,
                onPressed: () => _stopSession(),
                size: 56,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
              const SizedBox(width: AppDimensions.spacingLg),

              // Play / Pause button (prominent).
              LiquidGlassCard(
                onTap: isPaused ? _resumeSession : _pauseSession,
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
        SizedBox(height: MediaQuery.of(context).padding.bottom + 100),
      ],
    );
  }

  /// Cercle de respiration multi-couches avec la mascotte au centre.
  Widget _buildBreathingOrb(bool isDark, Color accent, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo externe pulsant.
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, _) {
              return Opacity(
                opacity: 0.6 + (_glowController.value * 0.25),
                child: Transform.scale(
                  scale: 1.05 + (_glowController.value * 0.08),
                  child: Container(
                    width: size * 0.867,
                    height: size * 0.867,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: 0.16),
                          accent.withValues(alpha: 0.04),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Anneau de progression de phase (CustomPaint).
          AnimatedBuilder(
            animation: Listenable.merge([_breathScale, _phaseRingController]),
            builder: (context, _) {
              final scale = 0.82 + (_breathScale.value * 0.18);
              return Transform.scale(
                scale: scale,
                child: SizedBox(
                  width: size * 0.80,
                  height: size * 0.80,
                  child: CustomPaint(
                    painter: _PhaseRingPainter(
                      progress: _phaseRingController.value.clamp(0.0, 1.0),
                      color: accent,
                      trackColor: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                ),
              );
            },
          ),

          // Cercle principal (gradient) qui se dilate/contracte.
          AnimatedBuilder(
            animation: _breathScale,
            builder: (context, _) {
              final scale = 0.78 + (_breathScale.value * 0.32);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: size * 0.667,
                  height: size * 0.667,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accent.withValues(alpha: 0.32),
                        accent.withValues(alpha: 0.10),
                        AppColors.primaryLight.withValues(alpha: 0.04),
                      ],
                      stops: const [0.0, 0.65, 1.0],
                    ),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.18),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Mascotte 3D au centre, qui respire en sync.
          AnimatedBuilder(
            animation: _breathScale,
            builder: (context, _) {
              final scale = 0.9 + (_breathScale.value * 0.12);
              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: 0.96,
                  child: MascotWithAccessories(
                    config: const Mascot3DConfig(
                      autoRotate: false,
                      interactionEnabled: false,
                      showLoadingIndicator: false,
                    ),
                    width: size * 0.467,
                    height: size * 0.50,
                  ),
                ),
              );
            },
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

  // ============================================================
  // Finished view – mascot celebration + stats + mood picker
  // ============================================================

  Widget _buildFinishedView(bool isDark) {
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final subtitleColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final accent = _selectedBreathingType.color;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.pageHorizontalPadding,
        vertical: AppDimensions.spacingLg,
      ),
      child: Column(
        children: [
          const SizedBox(height: AppDimensions.spacingMd),

          // Mascotte qui célèbre + halo.
          SizedBox(
            width: 200,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, _) {
                    return Transform.scale(
                      scale: 1.0 + (_glowController.value * 0.08),
                      child: Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.accent.withValues(alpha: 0.22),
                              AppColors.primary.withValues(alpha: 0.08),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const MascotWithAccessories(
                  config: Mascot3DConfig(
                    autoRotate: false,
                    interactionEnabled: false,
                    showLoadingIndicator: false,
                  ),
                  width: 160,
                  height: 170,
                ),
              ],
            ),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

          const SizedBox(height: AppDimensions.spacingSm),

          Text(
            'Bravo, c\'est terminé !',
            style: AppTextStyles.headlineMedium(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 600.ms, delay: 300.ms),

          const SizedBox(height: AppDimensions.spacingXs),

          Text(
            'Tu as pris un moment pour toi,\net c\'est déjà une belle victoire.',
            style: AppTextStyles.bodyMedium(color: subtitleColor),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 600.ms, delay: 500.ms),

          const SizedBox(height: AppDimensions.spacingXl),

          // Carte de stats de session.
          _buildSessionStats(isDark, textColor, subtitleColor, accent)
              .animate()
              .fadeIn(duration: 600.ms, delay: 600.ms)
              .slideY(begin: 0.15, end: 0),

          const SizedBox(height: AppDimensions.spacingXxl),

          // Mood question.
          Text(
            'Comment te sens-tu maintenant ?',
            style: AppTextStyles.titleMedium(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 600.ms, delay: 700.ms),

          const SizedBox(height: AppDimensions.spacingLg),

          // Mood emoji row.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _moods.asMap().entries.map((entry) {
              final index = entry.key;
              final mood = entry.value;
              final selected = _selectedMood == index;

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedMood = index);
                  unawaited(_completeBackendSession(moodAfter: mood.value));
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: selected
                        ? Border.all(
                            color: AppColors.primary.withValues(alpha: 0.45),
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: Column(
                    children: [
                      Icon(mood.icon, size: 30, color: mood.color),
                      const SizedBox(height: 4),
                      Text(
                        mood.label,
                        style: AppTextStyles.labelSmall(
                          color: selected ? AppColors.primary : subtitleColor,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(
                duration: 400.ms,
                delay: Duration(milliseconds: 800 + (index * 100)),
              );
            }).toList(),
          ),

          const SizedBox(height: AppDimensions.spacingXxl),

          // Back to setup button.
          if (_selectedMood != null)
            Center(
              child: LiquidGlassCard(
                onTap: () => _stopSession(finished: false),
                borderRadius: 30,
                padding: const EdgeInsets.symmetric(
                  horizontal: 36,
                  vertical: 14,
                ),
                color: AppColors.primary.withValues(alpha: 0.22),
                borderColor: AppColors.primary.withValues(alpha: 0.5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Nouvelle session',
                      style: AppTextStyles.labelLarge(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.15, end: 0),

          const SizedBox(height: AppDimensions.spacingXxl),
        ],
      ),
    );
  }

  /// Résumé visuel de la session terminée.
  Widget _buildSessionStats(
    bool isDark,
    Color textColor,
    Color subtitleColor,
    Color accent,
  ) {
    return LiquidGlassCard(
      borderRadius: AppDimensions.radiusLiquidGlassCard,
      padding: const EdgeInsets.all(AppDimensions.paddingLg),
      child: Column(
        children: [
          Row(
            children: [
              Icon(_selectedBreathingType.icon, color: accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _selectedBreathingType.label,
                  style: AppTextStyles.titleSmall(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Row(
            children: [
              Expanded(
                child: _buildStatColumn(
                  '$_selectedDurationMinutes',
                  'minutes',
                  Icons.timer_outlined,
                  accent,
                  textColor,
                  subtitleColor,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              ),
              Expanded(
                child: _buildStatColumn(
                  '$_completedCycles',
                  'cycles',
                  Icons.refresh_rounded,
                  accent,
                  textColor,
                  subtitleColor,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              ),
              Expanded(
                child: _buildStatColumn(
                  _formatTime(
                    _selectedDurationMinutes * 60 - _remainingSeconds,
                  ),
                  'respiré',
                  Icons.air_rounded,
                  accent,
                  textColor,
                  subtitleColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(
    String value,
    String label,
    IconData icon,
    Color accent,
    Color textColor,
    Color subtitleColor,
  ) {
    return Column(
      children: [
        Icon(icon, size: 18, color: accent),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppTextStyles.titleMedium(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.labelSmall(color: subtitleColor)),
      ],
    );
  }
}

// ============================================================
// Helper data class
// ============================================================

class _MoodOption {
  const _MoodOption(this.icon, this.label, this.value, this.color);
  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

// ============================================================
// Phase ring painter – progress around the breathing circle
// ============================================================

class _PhaseRingPainter extends CustomPainter {
  _PhaseRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 8;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Anneau de fond complet.
    canvas.drawCircle(center, radius, trackPaint);

    // Arc de progression.
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // départ en haut.
      sweepAngle,
      false,
      progressPaint,
    );

    // Petit point lumineux à la tête de l'arc.
    if (progress > 0.001) {
      final angle = -math.pi / 2 + sweepAngle;
      final dotOffset = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(dotOffset, 5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_PhaseRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
