import 'package:flutter/foundation.dart';
import '../../../../core/config/dev_session.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/gamification_models.dart';
import '../../data/repositories/gamification_repository.dart';

class GamificationProvider extends ChangeNotifier {
  final GamificationRepository _repository;
  final bool Function()? _isDemoSession;

  List<ChallengeTemplate> _availableChallenges = [];
  List<UserChallenge> _activeChallenges = [];
  List<UserChallenge> _completedChallenges = [];
  List<UserChallenge> _proposals = [];
  bool _isLoading = false;
  String? _error;

  GamificationProvider({
    GamificationRepository? repository,
    ApiClient? client,
    bool Function()? isDemoSession,
  }) : assert(
         repository != null || client != null,
         'repository or client must be provided',
       ),
       _repository = repository ?? GamificationRepository(client: client!),
       _isDemoSession = isDemoSession;

  List<ChallengeTemplate> get availableChallenges =>
      List.unmodifiable(_availableChallenges);
  List<UserChallenge> get activeChallenges =>
      List.unmodifiable(_activeChallenges);
  List<UserChallenge> get completedChallenges =>
      List.unmodifiable(_completedChallenges);
  List<UserChallenge> get proposals => List.unmodifiable(_proposals);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Charge toutes les données en parallèle
  Future<void> loadAll() async {
    if (_isDemoSession?.call() == true) {
      applyDevProgress();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository.getAvailableChallenges(),
        _repository.getActiveChallenges(),
        _repository.getCompletedChallenges(),
        _repository.getProposals(),
      ]);
      _availableChallenges = results[0] as List<ChallengeTemplate>;
      _activeChallenges = results[1] as List<UserChallenge>;
      _completedChallenges = results[2] as List<UserChallenge>;
      _proposals = results[3] as List<UserChallenge>;
    } catch (e) {
      _error = e.toString();
      debugPrint('[GamificationProvider] loadAll error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Progression locale du Mode Dev : tous les accessoires + niveau Jardin 5.
  @visibleForTesting
  void applyDevProgress() {
    final now = DateTime.now();
    _completedChallenges = List.generate(DevSession.completedChallengeCount, (
      index,
    ) {
      final id = 'demo-challenge-${index + 1}';
      return UserChallenge(
        id: 'demo-completed-${index + 1}',
        userId: DevSession.userId,
        challengeId: id,
        status: 'COMPLETED',
        progress: const {'current': 1, 'target': 1},
        createdAt: now,
        updatedAt: now,
        completedAt: now,
        template: ChallengeTemplate(
          id: id,
          title: 'Rituel démo ${index + 1}',
          description: 'Progression locale du Mode Dev',
          source: 'SYSTEM',
          rewardPoints: 50,
          aggregator: 'COUNT',
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
    _availableChallenges = const [];
    _activeChallenges = const [];
    _proposals = const [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// Démarre un défi SYSTEM et le déplace dans la liste active
  Future<bool> startChallenge(String challengeId) async {
    if (_isDemoSession?.call() == true) return true;
    try {
      await _repository.startChallenge(challengeId);
      await loadAll(); // Refresh everything to get updated streak and lists
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('[GamificationProvider] startChallenge error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Accepte une proposition IA et la déplace dans la liste active
  Future<bool> acceptChallenge(String challengeId) async {
    if (_isDemoSession?.call() == true) return true;
    try {
      await _repository.acceptChallenge(challengeId);
      await loadAll(); // Refresh everything
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Rejette une proposition IA
  Future<bool> rejectChallenge(String challengeId) async {
    if (_isDemoSession?.call() == true) return true;
    try {
      await _repository.rejectChallenge(challengeId);
      _proposals.removeWhere((c) => c.id == challengeId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> loadActive() async {
    if (_isDemoSession?.call() == true) {
      applyDevProgress();
      return;
    }
    try {
      _activeChallenges = await _repository.getActiveChallenges();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
