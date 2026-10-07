import 'package:flutter/foundation.dart';

import '../../../../core/config/dev_session.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/diagnostics/app_diagnostics.dart';
import '../../data/models/gamification_models.dart';
import '../../data/repositories/gamification_repository.dart';

class GamificationProvider extends ChangeNotifier {
  final GamificationRepository _repository;
  final bool Function()? _isDemoSession;
  String? _userId;
  bool _demo = false;
  int _sessionRevision = 0;
  int _loadRevision = 0;
  Future<void>? _loadFuture;
  final Set<String> _commands = {};
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

  List<ChallengeTemplate> _availableChallenges = const [];
  List<UserChallenge> _activeChallenges = const [];
  List<UserChallenge> _completedChallenges = const [];
  List<UserChallenge> _proposals = const [];
  bool _isLoading = false;
  String? _error;

  GamificationProvider({
    GamificationRepository? repository,
    ApiClient? client,
    this._isDemoSession,
  }) : assert(
         repository != null || client != null,
         'repository or client must be provided',
       ),
       _repository = repository ?? GamificationRepository(client: client!);

  void onUserChanged({String? userId, bool isDemo = false}) {
    if (_userId == userId && _demo == isDemo) return;
    resetSession();
    _userId = userId;
    _demo = isDemo;
  }

  void resetSession() {
    _sessionRevision++;
    _loadRevision++;
    _loadFuture = null;
    _commands.clear();
    _userId = null;
    _demo = false;
    _availableChallenges = const [];
    _activeChallenges = const [];
    _completedChallenges = const [];
    _proposals = const [];
    _isLoading = false;
    _error = null;
    _notify();
  }

  @visibleForTesting
  void applyDevProgress() {
    final now = DateTime.now();
    _completedChallenges = List.unmodifiable(
      List.generate(
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
      ),
    );
    _availableChallenges = const [];
    _activeChallenges = const [];
    _proposals = const [];
    _isLoading = false;
    _error = null;
    _notify();
  }

  List<ChallengeTemplate> get availableChallenges => _availableChallenges;
  List<UserChallenge> get activeChallenges => _activeChallenges;
  List<UserChallenge> get completedChallenges => _completedChallenges;
  List<UserChallenge> get proposals => _proposals;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Charge toutes les données en parallèle
  Future<void> loadAll() {
    if (_loadFuture != null) return _loadFuture!;
    late final Future<void> request;
    request = _loadAll().whenComplete(() {
      if (identical(_loadFuture, request)) _loadFuture = null;
    });
    return _loadFuture = request;
  }

  Future<void> _reloadAfterCommand() async {
    await _loadFuture;
    if (!_disposed) await loadAll();
  }

  Future<void> _loadAll() async {
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
      _availableChallenges = List.unmodifiable(
        results[0] as List<ChallengeTemplate>,
      );
      _activeChallenges = List.unmodifiable(results[1] as List<UserChallenge>);
      _completedChallenges = List.unmodifiable(
        results[2] as List<UserChallenge>,
      );
      _proposals = List.unmodifiable(results[3] as List<UserChallenge>);
    } catch (e) {
      if (session == _sessionRevision && request == _loadRevision) {
        _error = e is ApiException
            ? e.message
            : 'Impossible de synchroniser tes défis. Réessaie.';
        AppDiagnostics.record('challenges_load_failed', e);
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
    if (!_commands.add(challengeId)) return false;
    final session = _sessionRevision;
    try {
      await _repository.startChallenge(challengeId);
      if (session != _sessionRevision) return false;
      await _reloadAfterCommand(); // Refresh everything to get updated streak and lists
      return true;
    } catch (e) {
      if (session != _sessionRevision) return false;
      _error = e is ApiException
          ? e.message
          : 'Impossible de synchroniser tes défis. Réessaie.';
      AppDiagnostics.record('challenge_start_failed', e);
      _notify();
      return false;
    } finally {
      if (session == _sessionRevision) _commands.remove(challengeId);
    }
  }

  /// Accepte une proposition IA et la déplace dans la liste active
  Future<bool> acceptChallenge(String challengeId) async {
    if (_isDemo) return true;
    if (!_commands.add(challengeId)) return false;
    final session = _sessionRevision;
    try {
      await _repository.acceptChallenge(challengeId);
      if (session != _sessionRevision) return false;
      await _reloadAfterCommand(); // Refresh everything
      return true;
    } catch (e) {
      if (session != _sessionRevision) return false;
      _error = e is ApiException
          ? e.message
          : 'Impossible de synchroniser tes défis. Réessaie.';
      _notify();
      return false;
    } finally {
      if (session == _sessionRevision) _commands.remove(challengeId);
    }
  }

  /// Rejette une proposition IA
  Future<bool> rejectChallenge(String challengeId) async {
    if (_isDemo) return true;
    if (!_commands.add(challengeId)) return false;
    final session = _sessionRevision;
    try {
      await _repository.rejectChallenge(challengeId);
      if (session != _sessionRevision) return false;
      _proposals = List.unmodifiable(
        _proposals.where((c) => c.id != challengeId),
      );
      _notify();
      return true;
    } catch (e) {
      if (session != _sessionRevision) return false;
      _error = e is ApiException
          ? e.message
          : 'Impossible de synchroniser tes défis. Réessaie.';
      _notify();
      return false;
    } finally {
      if (session == _sessionRevision) _commands.remove(challengeId);
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
      _activeChallenges = List.unmodifiable(result);
      _notify();
    } catch (e) {
      if (session != _sessionRevision) return;
      _error = e is ApiException
          ? e.message
          : 'Impossible de synchroniser tes défis. Réessaie.';
      _notify();
    }
  }
}
