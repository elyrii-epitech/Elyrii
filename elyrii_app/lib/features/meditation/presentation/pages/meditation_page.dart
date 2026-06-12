import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/liquid_glass_kit.dart';

/// Breathing exercise types available in the meditation page.
enum BreathingType {
  /// 4-7-8 breathing: inhale 4s, hold 7s, exhale 8s
  relaxation478('Respiration 4-7-8', [4, 7, 8], 'Apaisante et profonde'),

  /// Box breathing: inhale 4s, hold 4s, exhale 4s, hold 4s
  carree('Respiration carrée', [4, 4, 4, 4], 'Équilibrante et calmante');

  const BreathingType(this.label, this.phases, this.description);

  /// French display label.
  final String label;

  /// Duration in seconds for each phase.
  /// 3 phases = inhale, hold, exhale.
  /// 4 phases = inhale, hold, exhale, hold.
  final List<int> phases;

  /// Short French description.
  final String description;

  /// Human-readable phase labels in French.
  List<String> get phaseLabels {
    switch (this) {
      case BreathingType.relaxation478:
        return ['Inspire...', 'Retiens...', 'Expire...'];
      case BreathingType.carree:
        return ['Inspire...', 'Retiens...', 'Expire...', 'Retiens...'];
    }
  }

  /// Total cycle duration in seconds.
  int get cycleDuration => phases.reduce((a, b) => a + b);
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

  // ---- Animation ----
  late AnimationController _circleScaleController;
  late AnimationController _glowController;

  /// Timer driving the breathing countdown.
  Timer? _timer;

  /// Whether the post-session mood has been picked.
  int? _selectedMood;

  // ---- Available durations (minutes) ----
  static const List<int> _durations = [5, 10, 15];

  // ---- Mood emoji list for post-session feedback ----
  static const List<_MoodOption> _moods = [
    _MoodOption(Icons.sentiment_very_dissatisfied_rounded, 'Pas bien',
        Color(0xFF7BA3C7)),
    _MoodOption(Icons.sentiment_neutral_rounded, 'Neutre', Color(0xFFA39C96)),
    _MoodOption(Icons.sentiment_satisfied_rounded, 'Bien', Color(0xFFA8D5BA)),
    _MoodOption(
        Icons.sentiment_satisfied_alt_rounded, 'Apaisé(e)', Color(0xFF7BC393)),
    _MoodOption(Icons.sentiment_very_satisfied_rounded, 'Merveilleux',
        Color(0xFF5FA87A)),
  ];

  // ============================================================
  // Lifecycle
  // ============================================================

  @override
  void initState() {
    super.initState();
    _remainingSeconds = _selectedDurationMinutes * 60;

    // Scale animation for the breathing circle (0 = contracted, 1 = expanded).
    _circleScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Subtle pulsing glow that loops.
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _circleScaleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  // ============================================================
  // Session control
  // ============================================================

  void _startSession() {
    setState(() {
      _sessionState = _SessionState.running;
      _remainingSeconds = _selectedDurationMinutes * 60;
      _currentPhaseIndex = 0;
      _phaseSecondsRemaining = _selectedBreathingType.phases.first;
      _selectedMood = null;
    });

    // Start with inhale → expand.
    _circleScaleController.forward();

    _startTimer();
  }

  void _pauseSession() {
    _timer?.cancel();
    setState(() => _sessionState = _SessionState.paused);
  }

  void _resumeSession() {
    setState(() => _sessionState = _SessionState.running);
    _startTimer();
  }

  void _stopSession({bool finished = false}) {
    _timer?.cancel();
    _circleScaleController.reverse();
    setState(() {
      _sessionState = finished ? _SessionState.finished : _SessionState.setup;
      if (!finished) _remainingSeconds = _selectedDurationMinutes * 60;
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
          _circleScaleController.reverse();
          _sessionState = _SessionState.finished;
        }
      });
    });
  }

  void _advancePhase() {
    final phases = _selectedBreathingType.phases;
    _currentPhaseIndex = (_currentPhaseIndex + 1) % phases.length;
    _phaseSecondsRemaining = phases[_currentPhaseIndex];

    // Animate circle.
    final isContracting =
        _selectedBreathingType.phaseLabels[_currentPhaseIndex] == 'Expire...';
    if (isContracting) {
      _circleScaleController.reverse();
    } else {
      _circleScaleController.forward();
    }
  }

  /// Format [seconds] as MM:SS.
  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.scaffoldDark : AppColors.scaffoldLight,
      body: SafeArea(
        child: Column(
          children: [
            // ---- Lottie decoration at top ----
            if (_sessionState != _SessionState.running &&
                _sessionState != _SessionState.paused)
              SizedBox(
                height: 100,
                child: Lottie.asset(
                  'assets/animations/breath.json',
                  fit: BoxFit.contain,
                  repeat: true,
                  animate: true,
                ),
              ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.1, end: 0),

            Expanded(child: _buildBody(isDark)),
          ],
        ),
      ),
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
    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final subtitleColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.pageHorizontalPadding,
        vertical: AppDimensions.spacingSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title.
          Center(
            child: Text(
              'Respire',
              style: AppTextStyles.headlineMedium(color: textColor),
            ),
          ).animate().fadeIn(duration: 600.ms),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Prends un moment pour toi',
              style: AppTextStyles.bodyMedium(color: subtitleColor),
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 200.ms),

          const SizedBox(height: AppDimensions.spacingXl),

          // Duration selector.
          Text(
            'Durée',
            style: AppTextStyles.titleMedium(color: textColor),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          _buildDurationChips(isDark),

          const SizedBox(height: AppDimensions.spacingXl),

          // Breathing type selector.
          Text(
            'Type d\'exercice',
            style: AppTextStyles.titleMedium(color: textColor),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          _buildBreathingTypeCards(isDark, textColor, subtitleColor),

          const SizedBox(height: AppDimensions.spacingXxl),

          // Start button.
          Center(
            child: LiquidGlassCard(
              onTap: _startSession,
              borderRadius: 30,
              padding: const EdgeInsets.symmetric(
                horizontal: 40,
                vertical: 16,
              ),
              color: AppColors.primary.withValues(alpha: 0.2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow_rounded,
                      color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Commencer',
                    style: AppTextStyles.labelLarge(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().slideY(begin: 0.2, end: 0, delay: 300.ms).fadeIn(),

          const SizedBox(height: AppDimensions.spacingXl),
        ],
      ),
    );
  }

  Widget _buildDurationChips(bool isDark) {
    return Row(
      children: _durations.map((d) {
        final selected = d == _selectedDurationMinutes;
        return Padding(
          padding: const EdgeInsets.only(right: AppDimensions.spacingSm),
          child: LiquidGlassCard(
            onTap: () => setState(() => _selectedDurationMinutes = d),
            borderRadius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: selected
                ? AppColors.primary.withValues(alpha: 0.25)
                : isDark
                    ? AppColors.liquidGlassBackgroundDark
                    : AppColors.liquidGlassBackgroundLight,
            borderColor:
                selected ? AppColors.primary.withValues(alpha: 0.5) : null,
            child: Text(
              '$d min',
              style: AppTextStyles.labelMedium(
                color: selected
                    ? AppColors.primary
                    : isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
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
                ? AppColors.primary.withValues(alpha: 0.12)
                : isDark
                    ? AppColors.liquidGlassBackgroundDark
                    : AppColors.liquidGlassBackgroundLight,
            borderColor:
                selected ? AppColors.primary.withValues(alpha: 0.4) : null,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.label,
                        style: AppTextStyles.titleSmall(
                          color: selected ? AppColors.primary : textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        type.description,
                        style: AppTextStyles.bodySmall(color: subtitleColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${type.phases.join('s – ')}s',
                        style: AppTextStyles.labelSmall(
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle,
                      color: AppColors.primary, size: 20),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ============================================================
  // Exercise view – animated breathing circle + controls
  // ============================================================

  Widget _buildExerciseView(bool isDark) {
    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final subtitleColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final currentPhaseLabel =
        _selectedBreathingType.phaseLabels[_currentPhaseIndex];
    final isPaused = _sessionState == _SessionState.paused;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 1),

        // Breathing type label.
        Text(
          _selectedBreathingType.label,
          style: AppTextStyles.titleMedium(color: subtitleColor),
        ),
        const SizedBox(height: AppDimensions.spacingLg),

        // ---- Animated breathing circle ----
        SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow: transform-only animation to avoid layout work.
              AnimatedBuilder(
                animation: _glowController,
                builder: (context, _) {
                  return Opacity(
                    opacity: 0.7 + (_glowController.value * 0.2),
                    child: Transform.scale(
                      scale: 1.0 + (_glowController.value * 0.12),
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.12),
                              AppColors.primary.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Main breathing circle.
              AnimatedBuilder(
                animation: _circleScaleController,
                builder: (context, _) {
                  final scale = 0.75 + (_circleScaleController.value * 0.35);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.35),
                            AppColors.primary.withValues(alpha: 0.10),
                            AppColors.primaryLight.withValues(alpha: 0.05),
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        ),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Phase text.
                            Text(
                              isPaused ? 'Pause' : currentPhaseLabel,
                              style: AppTextStyles.titleMedium(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            // Phase seconds remaining.
                            Text(
                              '$_phaseSecondsRemaining',
                              style: AppTextStyles.headlineMedium(
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: AppDimensions.spacingXl),

        // Global countdown.
        Text(
          _formatTime(_remainingSeconds),
          style: AppTextStyles.displaySmall(color: textColor),
        ),
        const SizedBox(height: 4),
        Text(
          'Temps restant',
          style: AppTextStyles.bodySmall(color: subtitleColor),
        ),

        const Spacer(flex: 1),

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
                color: AppColors.primary.withValues(alpha: 0.2),
                child: Icon(
                  isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppDimensions.spacingXxl),
      ],
    );
  }

  // ============================================================
  // Finished view – mood picker
  // ============================================================

  Widget _buildFinishedView(bool isDark) {
    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final subtitleColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.pageHorizontalPadding,
        vertical: AppDimensions.spacingLg,
      ),
      child: Column(
        children: [
          const SizedBox(height: AppDimensions.spacingXl),

          // Congratulatory text.
          const Icon(Icons.wb_sunny_rounded, color: AppColors.accent, size: 48)
              .animate()
              .scale(duration: 500.ms, curve: Curves.elasticOut),

          const SizedBox(height: AppDimensions.spacingLg),

          Text(
            'Bravo, c\'est terminé !',
            style: AppTextStyles.headlineSmall(color: textColor),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 600.ms, delay: 300.ms),

          const SizedBox(height: AppDimensions.spacingSm),

          Text(
            'Tu as pris un moment pour toi,\net c\'est déjà une belle victoire.',
            style: AppTextStyles.bodyMedium(color: subtitleColor),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 600.ms, delay: 500.ms),

          const SizedBox(height: AppDimensions.spacingXxl),

          // Mood question.
          Text(
            'Comment te sens-tu maintenant ?',
            style: AppTextStyles.titleMedium(color: textColor),
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
                onTap: () => setState(() => _selectedMood = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: selected
                        ? Border.all(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: Column(
                    children: [
                      Icon(mood.icon, size: 32, color: mood.color),
                      const SizedBox(height: 4),
                      Text(
                        mood.label,
                        style: AppTextStyles.labelSmall(
                          color: selected ? AppColors.primary : subtitleColor,
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
                onTap: () => _stopSession(),
                borderRadius: 30,
                padding: const EdgeInsets.symmetric(
                  horizontal: 36,
                  vertical: 14,
                ),
                color: AppColors.primary.withValues(alpha: 0.2),
                child: Text(
                  'Revenir',
                  style: AppTextStyles.labelLarge(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.15, end: 0),

          const SizedBox(height: AppDimensions.spacingXl),
        ],
      ),
    );
  }
}

// ============================================================
// Helper data class
// ============================================================

class _MoodOption {
  const _MoodOption(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;
}
