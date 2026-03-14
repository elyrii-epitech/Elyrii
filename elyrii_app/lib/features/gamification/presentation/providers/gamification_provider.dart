import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/gamification_models.dart';
import '../../data/repositories/gamification_repository.dart';

/// Provider managing gamification/quest state
class GamificationProvider extends ChangeNotifier {
  final GamificationRepository _repository;

  List<UserChallenge> _activeChallenges = [];
  List<UserChallenge> _completedChallenges = [];
  List<UserChallenge> _proposals = [];
  bool _isLoading = false;
  String? _error;

  GamificationProvider({required ApiClient client})
      : _repository = GamificationRepository(client: client);

  List<UserChallenge> get activeChallenges =>
      List.unmodifiable(_activeChallenges);
  List<UserChallenge> get completedChallenges =>
      List.unmodifiable(_completedChallenges);
  List<UserChallenge> get proposals => List.unmodifiable(_proposals);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all challenge data from the backend
  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository.getActiveChallenges(),
        _repository.getCompletedChallenges(),
        _repository.getProposals(),
      ]);
      _activeChallenges = results[0];
      _completedChallenges = results[1];
      _proposals = results[2];
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load only active challenges
  Future<void> loadActive() async {
    try {
      _activeChallenges = await _repository.getActiveChallenges();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Load only proposals
  Future<void> loadProposals() async {
    try {
      _proposals = await _repository.getProposals();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Accept a proposed challenge
  Future<bool> acceptChallenge(String challengeId) async {
    try {
      final updated = await _repository.acceptChallenge(challengeId);
      _proposals.removeWhere((c) => c.id == challengeId);
      _activeChallenges.add(updated);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Reject a proposed challenge
  Future<bool> rejectChallenge(String challengeId) async {
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
}
