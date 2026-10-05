import 'package:flutter/foundation.dart';
import '../../../../core/config/dev_session.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/gamification_models.dart';
import '../../data/repositories/gamification_repository.dart';

class GamificationProvider extends ChangeNotifier {
  final GamificationRepository _repository;
  final bool Function()? _isDemoSession;
  String? _userId;
  bool _demo = false;
  int _sessionRevision = 0;
  int _loadRevision = 0;
  bool _disposed = false;

  bool get _isDemo => _demo || _isDemoSession?.call() == true;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

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

  void onUserChanged({String? userId, bool isDemo = false}) {
    if (_userId == userId && _demo == isDemo) return;
    resetSession();
    _userId = userId;
    _demo = isDemo;
  }

  void resetSession() {
    _sessionRevision++;
    _loadRevision++;
    _userId = null;
    _demo = false;
    _availableChallenges = [];
    _activeChallenges = [];
    _completedChallenges = [];
    _proposals = [];
    _isLoading = false;
    _error = null;
    _notify();
  }

  @visibleForTesting
  void applyDevProgress() {
    final now = DateTime.now();
    _completedChallenges = List.generate(
      DevSession.completedChallengeCount,
      (index) => UserChallenge(
        id: 'demo-completed-$index',
        userId: DevSession.userId,
        challengeId: 'demo-challenge-$index',
        status: 'COMPLETED',
        createdAt: now,
        updatedAt: now,
        completedAt: now,
      ),
    );
    _availableChallenges = [];
    _activeChallenges = [];
    _proposals = [];
    _isLoading = false;
    _error = null;
    _notify();
  }

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
    if (_isDemo) {
      applyDevProgress();
      return;
    }
    final session = _sessionRevision;
    final request = ++_loadRevision;
    _isLoading = true;
    _error = null;
    _notify();
    try {
      final results = await Future.wait([
        _repository.getAvailableChallenges(),
        _repository.getActiveChallenges(),
        _repository.getCompletedChallenges(),
        _repository.getProposals(),
      ]);
      if (session != _sessionRevision || request != _loadRevision) return;
      _availableChallenges = results[0] as List<ChallengeTemplate>;
      _activeChallenges = results[1] as List<UserChallenge>;
      _completedChallenges = results[2] as List<UserChallenge>;
      _proposals = results[3] as List<UserChallenge>;
    } catch (e) {
      if (session == _sessionRevision && request == _loadRevision) {
        _error = e.toString();
        debugPrint('[GamificationProvider] loadAll error: $e');
      }
    } finally {
      if (session == _sessionRevision && request == _loadRevision) {
        _isLoading = false;
        _notify();
      }
    }
  }

  /// Démarre un défi SYSTEM et le déplace dans la liste active
  Future<bool> startChallenge(String challengeId) async {
    if (_isDemo) return true;
    final session = _sessionRevision;
    try {
      await _repository.startChallenge(challengeId);
      if (session != _sessionRevision) return false;
      await loadAll(); // Refresh everything to get updated streak and lists
      return true;
    } catch (e) {
      if (session != _sessionRevision) return false;
      _error = e.toString();
      debugPrint('[GamificationProvider] startChallenge error: $e');
      _notify();
      return false;
    }
  }

  /// Accepte une proposition IA et la déplace dans la liste active
  Future<bool> acceptChallenge(String challengeId) async {
    if (_isDemo) return true;
    final session = _sessionRevision;
    try {
      await _repository.acceptChallenge(challengeId);
      if (session != _sessionRevision) return false;
      await loadAll(); // Refresh everything
      return true;
    } catch (e) {
      if (session != _sessionRevision) return false;
      _error = e.toString();
      _notify();
      return false;
    }
  }

  /// Rejette une proposition IA
  Future<bool> rejectChallenge(String challengeId) async {
    if (_isDemo) return true;
    final session = _sessionRevision;
    try {
      await _repository.rejectChallenge(challengeId);
      if (session != _sessionRevision) return false;
      _proposals.removeWhere((c) => c.id == challengeId);
      _notify();
      return true;
    } catch (e) {
      if (session != _sessionRevision) return false;
      _error = e.toString();
      _notify();
      return false;
    }
  }

  Future<void> loadActive() async {
    if (_isDemo) {
      applyDevProgress();
      return;
    }
    final session = _sessionRevision;
    try {
      final result = await _repository.getActiveChallenges();
      if (session != _sessionRevision) return;
      _activeChallenges = result;
      _notify();
    } catch (e) {
      if (session != _sessionRevision) return;
      _error = e.toString();
      _notify();
    }
  }
}
