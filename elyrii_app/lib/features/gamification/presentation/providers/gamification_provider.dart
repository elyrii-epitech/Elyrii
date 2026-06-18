import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/gamification_models.dart';
import '../../data/repositories/gamification_repository.dart';

class GamificationProvider extends ChangeNotifier {
  final GamificationRepository _repository;

  List<ChallengeTemplate> _availableChallenges = [];
  List<UserChallenge> _activeChallenges = [];
  List<UserChallenge> _completedChallenges = [];
  List<UserChallenge> _proposals = [];
  bool _isLoading = false;
  String? _error;

  GamificationProvider({required ApiClient client})
    : _repository = GamificationRepository(client: client);

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

  /// Démarre un défi SYSTEM et le déplace dans la liste active
  Future<bool> startChallenge(String challengeId) async {
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
    try {
      _activeChallenges = await _repository.getActiveChallenges();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
