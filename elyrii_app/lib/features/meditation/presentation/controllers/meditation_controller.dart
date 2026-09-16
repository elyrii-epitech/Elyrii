import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../data/repositories/meditation_repository.dart';
import '../../domain/models/breath_phase.dart';

/// États possibles d'une session de méditation.
enum MeditationSessionState { setup, running, paused, finished }

/// Contrôleur gérant l'état et le chronométrage de la respiration guidée.
/// Totalement découplé de l'arbre de widgets pour une testabilité unitaire maximale.
class MeditationController extends ChangeNotifier {
  final MeditationRepository? _repository;

  // Options sélectionnées
  int _selectedDurationMinutes = 5;
  BreathingType _selectedBreathingType = BreathingType.relaxation478;

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

  Timer? _timer;

  MeditationController({MeditationRepository? repository})
    : _repository = repository;

  // Getters
  int get selectedDurationMinutes => _selectedDurationMinutes;
  BreathingType get selectedBreathingType => _selectedBreathingType;
  MeditationSessionState get sessionState => _sessionState;
  int get remainingSeconds => _remainingSeconds;
  int get currentPhaseIndex => _currentPhaseIndex;
  int get phaseSecondsRemaining => _phaseSecondsRemaining;
  int get completedCycles => _completedCycles;
  String? get backendSessionId => _backendSessionId;
  String? get backendError => _backendError;
  bool get isStartingSession => _isStartingSession;
  int? get selectedMoodIndex => _selectedMoodIndex;

  bool get isRunning => _sessionState == MeditationSessionState.running;
  bool get isPaused => _sessionState == MeditationSessionState.paused;
  bool get isFinished => _sessionState == MeditationSessionState.finished;
  bool get isSetup => _sessionState == MeditationSessionState.setup;

  BreathPhase get currentPhase =>
      _selectedBreathingType.phases[_currentPhaseIndex];

  double get progressRatio {
    final total = _selectedDurationMinutes * 60;
    if (total == 0) return 0.0;
    return (1.0 - (_remainingSeconds / total)).clamp(0.0, 1.0);
  }

  void setDuration(int minutes) {
    if (_sessionState != MeditationSessionState.setup) return;
    _selectedDurationMinutes = minutes;
    _remainingSeconds = minutes * 60;
    notifyListeners();
  }

  void setBreathingType(BreathingType type) {
    if (_sessionState != MeditationSessionState.setup) return;
    _selectedBreathingType = type;
    notifyListeners();
  }

  Future<void> startSession() async {
    _sessionState = MeditationSessionState.running;
    _remainingSeconds = _selectedDurationMinutes * 60;
    _currentPhaseIndex = 0;
    _completedCycles = 0;
    _phaseSecondsRemaining = _selectedBreathingType.phases[0].seconds;
    _selectedMoodIndex = null;
    _backendError = null;

    ElyriiHaptics.medium();
    _startTimer();
    notifyListeners();

    // Async backend session registration
    if (_repository != null) {
      _isStartingSession = true;
      try {
        final session = await _repository.startSession(
          type: _selectedBreathingType.name,
          durationMinutes: _selectedDurationMinutes,
        );
        _backendSessionId = session.id;
      } catch (e) {
        _backendError = 'Synchronisation locale (hors ligne)';
      } finally {
        _isStartingSession = false;
        notifyListeners();
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
      _sessionState = MeditationSessionState.finished;
      ElyriiHaptics.success();
    } else {
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
  }

  Future<void> selectMood(int moodIndex, String backendKey) async {
    _selectedMoodIndex = moodIndex;
    ElyriiHaptics.selection();
    notifyListeners();

    if (_repository != null && _backendSessionId != null) {
      try {
        await _repository.completeSession(
          sessionId: _backendSessionId!,
          moodAfter: backendKey,
        );
      } catch (e) {
        debugPrint('[MeditationController] Complete session failed: $e');
      }
    }
  }

  void resetToSetup() {
    _timer?.cancel();
    _sessionState = MeditationSessionState.setup;
    _remainingSeconds = _selectedDurationMinutes * 60;
    _currentPhaseIndex = 0;
    _phaseSecondsRemaining = 0;
    _completedCycles = 0;
    _backendSessionId = null;
    _selectedMoodIndex = null;
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

    if (_remainingSeconds <= 1) {
      _remainingSeconds = 0;
      stopSession(finished: true);
      return;
    }

    _remainingSeconds--;

    if (_phaseSecondsRemaining <= 1) {
      // Transition vers la phase suivante
      final phases = _selectedBreathingType.phases;
      final nextIndex = (_currentPhaseIndex + 1) % phases.length;

      if (nextIndex == 0) {
        _completedCycles++;
      }

      _currentPhaseIndex = nextIndex;
      _phaseSecondsRemaining = phases[nextIndex].seconds;

      // Vibration haptique à chaque transition de phase
      ElyriiHaptics.light();
    } else {
      _phaseSecondsRemaining--;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
