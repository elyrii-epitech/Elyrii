import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../data/repositories/meditation_repository.dart';
import '../../domain/models/breath_phase.dart';
import '../../domain/models/meditation_exercise.dart';
import '../../domain/models/meditation_exercises.dart';

enum MeditationSessionState { setup, running, paused, finished }

class MeditationController extends ChangeNotifier {
  final MeditationRepository? _repository;

  int _selectedDurationMinutes = 5;
  MeditationExercise? _selectedExercise;

  static const minDurationMinutes = 1;
  static const maxDurationMinutes = 23 * 60 + 59;

  MeditationSessionState _sessionState = MeditationSessionState.setup;
  int _remainingSeconds = 300;
  int _currentPhaseIndex = 0;
  int _phaseSecondsRemaining = 0;
  int _completedCycles = 0;

  String? _backendSessionId;
  String? _backendError;
  int? _selectedMoodIndex;
  bool _disposed = false;
  Future<void> _completion = Future.value();
  int _pendingSaves = 0;
  _SessionRegistration? _registration;

  Timer? _timer;
  final Stopwatch _clock = Stopwatch();
  final Duration Function()? _elapsed;
  int _clockSeconds = 0;

  MeditationController({this._repository, this._elapsed});

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
  bool get isSyncing => _pendingSaves > 0;
  Future<void> get synchronized => _completion;
  int? get selectedMoodIndex => _selectedMoodIndex;

  bool get isRunning => _sessionState == MeditationSessionState.running;
  bool get isPaused => _sessionState == MeditationSessionState.paused;
  bool get isFinished => _sessionState == MeditationSessionState.finished;
  bool get isSetup => _sessionState == MeditationSessionState.setup;

  /// Breathing-only phase. Written guidance uses [currentGuidanceStep] and
  /// preserves natural breathing.
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
    final registration = _SessionRegistration(
      exercise.id,
      _selectedDurationMinutes,
    );
    _registration = registration;

    _sessionState = MeditationSessionState.running;
    _remainingSeconds = _selectedDurationMinutes * 60;
    _currentPhaseIndex = 0;
    _completedCycles = 0;
    _phaseSecondsRemaining = exercise.breathingType?.phases[0].seconds ?? 0;
    _selectedMoodIndex = null;
    _backendError = null;
    _backendSessionId = null;

    ElyriiHaptics.medium();
    _startTimer();
    notifyListeners();

    await _persist(registration);
  }

  void pauseSession() {
    if (_sessionState != MeditationSessionState.running) return;
    synchronizeClock();
    if (!isRunning) return;
    _timer?.cancel();
    _clock.stop();
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
    _clock.stop();
    final registration = _registration;

    if (finished) {
      _registration?.finished = true;
      _sessionState = MeditationSessionState.finished;
      ElyriiHaptics.success();
    } else {
      if (registration != null) registration.canceled = true;
      _sessionState = MeditationSessionState.setup;
      _remainingSeconds = _selectedDurationMinutes * 60;
      _backendSessionId = null;
      ElyriiHaptics.warning();
    }
    notifyListeners();
    if (registration != null) {
      final saving = _persist(registration);
      // Network registration never blocks the local finish/exit interaction.
      if (registration.backendId != null) await saving;
    }
  }

  Future<void> selectMood(int moodIndex, String backendKey) async {
    if (!isFinished || _disposed) return;
    _selectedMoodIndex = moodIndex;
    _registration?.mood = backendKey;
    ElyriiHaptics.selection();
    notifyListeners();

    final registration = _registration;
    if (registration != null) {
      final saving = _persist(registration);
      if (registration.backendId != null) await saving;
    }
  }

  Future<void> retrySync() async {
    final registration = _registration;
    if (_disposed || registration == null || isSyncing) return;
    await _persist(registration);
  }

  Future<void> _persist(_SessionRegistration registration) {
    if (_repository == null) return Future.value();
    _pendingSaves++;
    if (!_disposed &&
        identical(_registration, registration) &&
        !registration.canceled) {
      notifyListeners();
    }
    // Serialize acknowledgements, optional mood changes and retries. A captured
    // registration keeps its outcome even after closing its summary.
    _completion = _completion.then((_) async {
      try {
        registration.backendId ??= (await _repository.startSession(
          type: registration.type,
          durationMinutes: registration.minutes,
          clientSessionId: registration.clientId,
        )).id;
        if (registration.finished &&
            (!registration.completed ||
                registration.savedMood != registration.mood)) {
          final mood = registration.mood;
          await _repository.completeSession(
            sessionId: registration.backendId!,
            moodAfter: mood,
          );
          registration.completed = true;
          registration.savedMood = mood;
        } else if (registration.canceled && !registration.canceledSaved) {
          await _repository.cancelSession(registration.backendId!);
          registration.canceledSaved = true;
        }
        if (!_disposed && identical(_registration, registration)) {
          _backendError = null;
          if (!registration.canceled) {
            _backendSessionId = registration.backendId;
          }
        }
      } catch (_) {
        if (!_disposed && identical(_registration, registration)) {
          _backendError =
              'La séance n’a pas pu être enregistrée dans ton compte.';
        }
      } finally {
        _pendingSaves--;
        if (!_disposed &&
            identical(_registration, registration) &&
            !registration.canceled) {
          notifyListeners();
        }
      }
    });
    return _completion;
  }

  void resetToSetup() {
    _timer?.cancel();
    final previous = _registration;
    if (previous != null && !previous.finished && !previous.canceled) {
      previous.canceled = true;
      unawaited(_persist(previous));
    }
    _sessionState = MeditationSessionState.setup;
    _remainingSeconds = _selectedDurationMinutes * 60;
    _currentPhaseIndex = 0;
    _phaseSecondsRemaining = 0;
    _completedCycles = 0;
    _backendSessionId = null;
    _selectedMoodIndex = null;
    _selectedExercise = null;
    _registration = null;
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _clock
      ..reset()
      ..start();
    _clockSeconds = _elapsed?.call().inSeconds ?? 0;
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => synchronizeClock(),
    );
  }

  /// Read monotonic elapsed time; delayed callbacks never extend a session.
  /// Backgrounding pauses the session through the page lifecycle observer.
  @visibleForTesting
  void synchronizeClock() {
    if (!isRunning || _disposed) return;
    final seconds = (_elapsed?.call() ?? _clock.elapsed).inSeconds;
    final delta = seconds - _clockSeconds;
    if (delta <= 0) return;
    _clockSeconds = seconds;
    _advance(delta);
  }

  /// Explicit one-second step for deterministic domain tests.
  @visibleForTesting
  void tick() => _advance(1);

  void _advance(int seconds) {
    if (!isRunning || _disposed) return;
    final steps = seconds.clamp(0, _remainingSeconds);
    var changedPhase = false;
    for (var i = 0; i < steps; i++) {
      _remainingSeconds--;
      if (selectedBreathingType != null && !isBreathingRecovery) {
        if (_phaseSecondsRemaining <= 1) {
          final phases = selectedBreathingType!.phases;
          final next = (_currentPhaseIndex + 1) % phases.length;
          if (next == 0) _completedCycles++;
          _currentPhaseIndex = isBreathingRecovery ? -1 : next;
          _phaseSecondsRemaining = isBreathingRecovery
              ? 0
              : phases[next].seconds;
          changedPhase = true;
        } else {
          _phaseSecondsRemaining--;
        }
      }
    }
    if (changedPhase) ElyriiHaptics.light();
    if (_remainingSeconds == 0) {
      unawaited(stopSession(finished: true));
    } else if (steps > 0) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _clock.stop();
    final registration = _registration;
    if (registration != null &&
        !registration.finished &&
        !registration.canceled) {
      registration.canceled = true;
      unawaited(_persist(registration));
    }
    super.dispose();
  }
}

/// Keeps a finished session's outcome even after leaving its summary page.
class _SessionRegistration {
  final clientId = const Uuid().v4();
  final String type;
  final int minutes;
  String? backendId;
  bool finished = false;
  bool canceled = false;
  bool completed = false;
  bool canceledSaved = false;
  String? mood;
  String? savedMood;
  _SessionRegistration(this.type, this.minutes);
}
