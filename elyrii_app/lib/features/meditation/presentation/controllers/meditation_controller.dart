import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../data/repositories/meditation_repository.dart';
import '../../domain/models/breath_phase.dart';
import '../../domain/models/meditation_exercise.dart';
import '../../domain/models/meditation_exercises.dart';

/// États possibles d'une session de méditation.
enum MeditationSessionState { setup, running, paused, finished }

/// Chronométrage des respirations et des pratiques à guidage écrit.
/// Totalement découplé de l'arbre de widgets pour une testabilité unitaire maximale.
class MeditationController extends ChangeNotifier {
  final MeditationRepository? _repository;

  // Options sélectionnées (aucune intention présélectionnée : l'utilisateur choisit)
  int _selectedDurationMinutes = 5;
  MeditationExercise? _selectedExercise;

  static const minDurationMinutes = 1;
  static const maxDurationMinutes = 23 * 60 + 59;

  // État de la session
  MeditationSessionState _sessionState = MeditationSessionState.setup;
  int _remainingSeconds = 300;
  int _currentPhaseIndex = 0;
  int _phaseSecondsRemaining = 0;
  int _completedCycles = 0;

  // Backend sync
  String? _backendSessionId;
  String? _backendError;
  bool _isStartingSession = false;
  int? _selectedMoodIndex;
  String? _selectedMoodKey;
  int _generation = 0;
  bool _disposed = false;
  Future<void> _completion = Future.value();
  _SessionRegistration? _registration;

  Timer? _timer;

  MeditationController({MeditationRepository? repository})
    : _repository = repository;

  // Getters
  int get selectedDurationMinutes => _selectedDurationMinutes;
  Duration get selectedDuration => Duration(minutes: _selectedDurationMinutes);
  String get selectedDurationLabel => formatDuration(selectedDuration);

  /// A compact duration label shared by setup, the picker and the summary.
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours == 0) return '$minutes min';
    if (minutes == 0) return '$hours h';
    return '$hours h $minutes min';
  }

  MeditationExercise? get selectedExercise => _selectedExercise;
  BreathingType? get selectedBreathingType => _selectedExercise?.breathingType;
  bool get isGuidedPractice =>
      _selectedExercise != null && !_selectedExercise!.isBreathing;
  bool get isBreathingRecovery =>
      selectedBreathingType == BreathingType.relaxation478 &&
      _completedCycles >= 4;
  MeditationSessionState get sessionState => _sessionState;
  int get remainingSeconds => _remainingSeconds;
  String get formattedRemainingTime => formatCountdown(_remainingSeconds);

  static String formatCountdown(int totalSeconds) {
    final hours = totalSeconds ~/ Duration.secondsPerHour;
    final minutes = (totalSeconds ~/ Duration.secondsPerMinute).remainder(60);
    final seconds = totalSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours == 0) return '${minutes.toString().padLeft(2, '0')}:$seconds';
    return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
  }

  int get currentPhaseIndex => _currentPhaseIndex;
  int get phaseSecondsRemaining =>
      isBreathingRecovery ? _remainingSeconds : _phaseSecondsRemaining;
  int get completedCycles => _completedCycles;
  String? get backendSessionId => _backendSessionId;
  String? get backendError => _backendError;
  bool get isStartingSession => _isStartingSession;
  int? get selectedMoodIndex => _selectedMoodIndex;

  bool get isRunning => _sessionState == MeditationSessionState.running;
  bool get isPaused => _sessionState == MeditationSessionState.paused;
  bool get isFinished => _sessionState == MeditationSessionState.finished;
  bool get isSetup => _sessionState == MeditationSessionState.setup;

  /// Phase des respirations uniquement. Le guidage écrit utilise
  /// [currentGuidanceStep] et conserve un souffle naturel.
  BreathPhase get currentPhase => isBreathingRecovery
      ? BreathPhase(_remainingSeconds, 'Souffle libre', BreathAction.hold)
      : selectedBreathingType!.phases[_currentPhaseIndex];

  /// Every step gets a proportion of the chosen duration, including the ending.
  int get currentGuidanceStepIndex {
    final steps = _selectedExercise!.steps;
    final totalWeight = steps.fold(0, (sum, step) => sum + step.weight);
    final totalSeconds = _selectedDurationMinutes * 60;
    final elapsed = totalSeconds - _remainingSeconds;
    var cumulative = 0;
    for (var i = 0; i < steps.length; i++) {
      cumulative += steps[i].weight;
      if (elapsed * totalWeight < cumulative * totalSeconds) return i;
    }
    return steps.length - 1;
  }

  MeditationStep get currentGuidanceStep =>
      _selectedExercise!.steps[currentGuidanceStepIndex];

  double get progressRatio {
    final total = _selectedDurationMinutes * 60;
    if (total == 0) return 0.0;
    return (1.0 - (_remainingSeconds / total)).clamp(0.0, 1.0);
  }

  void setSessionDuration(Duration duration) {
    if (_sessionState != MeditationSessionState.setup) return;
    if (duration.inMicroseconds % Duration.microsecondsPerMinute != 0) {
      throw ArgumentError.value(duration, 'duration', 'Choose whole minutes.');
    }
    setDuration(duration.inMinutes);
  }

  void setDuration(int minutes) {
    if (_sessionState != MeditationSessionState.setup) return;
    RangeError.checkValueInInterval(
      minutes,
      minDurationMinutes,
      maxDurationMinutes,
      'minutes',
    );
    _selectedDurationMinutes = minutes;
    _remainingSeconds = minutes * 60;
    notifyListeners();
  }

  void setBreathingType(BreathingType type) {
    setExercise(MeditationExercises.forBreathingType(type));
  }

  void setExercise(MeditationExercise exercise) {
    if (_sessionState != MeditationSessionState.setup) return;
    _selectedExercise = exercise;
    notifyListeners();
  }

  Future<void> startSession() async {
    final exercise = _selectedExercise;
    if (exercise == null || !isSetup) return;
    final generation = ++_generation;
    final registration = _SessionRegistration();
    _registration = registration;

    _sessionState = MeditationSessionState.running;
    _remainingSeconds = _selectedDurationMinutes * 60;
    _currentPhaseIndex = 0;
    _completedCycles = 0;
    _phaseSecondsRemaining = exercise.breathingType?.phases[0].seconds ?? 0;
    _selectedMoodIndex = null;
    _selectedMoodKey = null;
    _backendError = null;
    _backendSessionId = null;
    _isStartingSession = _repository != null;

    ElyriiHaptics.medium();
    _startTimer();
    notifyListeners();

    // Async backend session registration
    if (_repository != null) {
      try {
        final session = await _repository.startSession(
          type: exercise.id,
          durationMinutes: _selectedDurationMinutes,
        );
        if (_disposed || generation != _generation) {
          if (registration.finished) {
            await _completeSession(session.id, registration.mood);
          } else {
            await _repository.cancelSession(session.id);
          }
          return;
        }
        _backendSessionId = session.id;
        if (isFinished) {
          unawaited(_completeSession(session.id, _selectedMoodKey));
        }
      } catch (e) {
        if (!_disposed && generation == _generation) {
          _backendError = 'Séance non synchronisée avec ton compte.';
        }
      } finally {
        if (!_disposed && generation == _generation) {
          _isStartingSession = false;
          notifyListeners();
        }
      }
    }
  }

  void pauseSession() {
    if (_sessionState != MeditationSessionState.running) return;
    _timer?.cancel();
    _sessionState = MeditationSessionState.paused;
    ElyriiHaptics.light();
    notifyListeners();
  }

  void resumeSession() {
    if (_sessionState != MeditationSessionState.paused) return;
    _sessionState = MeditationSessionState.running;
    ElyriiHaptics.light();
    _startTimer();
    notifyListeners();
  }

  Future<void> stopSession({bool finished = false}) async {
    _timer?.cancel();
    final previousSessionId = _backendSessionId;

    if (finished) {
      _registration?.finished = true;
      _sessionState = MeditationSessionState.finished;
      ElyriiHaptics.success();
    } else {
      _generation++;
      _isStartingSession = false;
      _sessionState = MeditationSessionState.setup;
      _remainingSeconds = _selectedDurationMinutes * 60;
      _backendSessionId = null;
      ElyriiHaptics.warning();

      if (_repository != null && previousSessionId != null) {
        unawaited(
          _repository
              .cancelSession(previousSessionId)
              .then((_) => null, onError: (_) => null),
        );
      }
    }
    notifyListeners();
    if (finished && previousSessionId != null) {
      await _completeSession(previousSessionId, _selectedMoodKey);
    }
  }

  Future<void> selectMood(int moodIndex, String backendKey) async {
    _selectedMoodIndex = moodIndex;
    _selectedMoodKey = backendKey;
    _registration?.mood = backendKey;
    ElyriiHaptics.selection();
    notifyListeners();

    if (_repository != null && _backendSessionId != null) {
      await _completeSession(_backendSessionId!, backendKey);
    }
  }

  Future<void> _completeSession(String id, String? mood) {
    // Keep the optional mood update after the automatic completion request.
    _completion = _completion.then((_) async {
      try {
        await _repository!.completeSession(sessionId: id, moodAfter: mood);
      } catch (_) {
        if (!_disposed && _backendSessionId == id) {
          _backendError = 'Séance non synchronisée avec ton compte.';
          notifyListeners();
        }
      }
    });
    return _completion;
  }

  void resetToSetup() {
    _timer?.cancel();
    _generation++;
    _isStartingSession = false;
    _sessionState = MeditationSessionState.setup;
    _remainingSeconds = _selectedDurationMinutes * 60;
    _currentPhaseIndex = 0;
    _phaseSecondsRemaining = 0;
    _completedCycles = 0;
    _backendSessionId = null;
    _selectedMoodIndex = null;
    _selectedMoodKey = null;
    _selectedExercise = null;
    _registration = null;
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      tick();
    });
  }

  /// Exécute un pas de temps (1 seconde) dans l'exercice.
  /// Méthode publique pour permettre un test unitaire déterministe sans attendre l'horloge système.
  void tick() {
    if (_sessionState != MeditationSessionState.running) return;

    _remainingSeconds--;

    if (selectedBreathingType != null &&
        !isBreathingRecovery &&
        _phaseSecondsRemaining <= 1) {
      // Transition vers la phase suivante
      final phases = selectedBreathingType!.phases;
      final nextIndex = (_currentPhaseIndex + 1) % phases.length;

      if (nextIndex == 0) {
        _completedCycles++;
      }

      _currentPhaseIndex = isBreathingRecovery ? -1 : nextIndex;
      _phaseSecondsRemaining = isBreathingRecovery
          ? 0
          : phases[nextIndex].seconds;

      // Vibration haptique à chaque transition de phase
      ElyriiHaptics.light();
    } else if (selectedBreathingType != null && !isBreathingRecovery) {
      _phaseSecondsRemaining--;
    }

    if (_remainingSeconds == 0) {
      stopSession(finished: true);
      return;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

/// Keeps a finished session's outcome even after leaving its summary page.
class _SessionRegistration {
  bool finished = false;
  String? mood;
}
