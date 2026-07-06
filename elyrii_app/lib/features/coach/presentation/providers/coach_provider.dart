import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/coach_model.dart';
import '../../data/repositories/coach_repository.dart';

class CoachProvider extends ChangeNotifier {
  final CoachRepository _repository;

  DailyAdvice? _todayAdvice;
  List<CoachActivity> _recommendedActivities = [];
  List<CoachActivity> _allActivities = [];
  List<CoachSession> _sessions = [];
  bool _isLoading = false;
  bool _isCreatingSession = false;
  bool _hasLoadedRemote = false;
  String? _error;

  DailyAdvice? get todayAdvice => _todayAdvice;
  List<CoachActivity> get recommendedActivities => _recommendedActivities;
  List<CoachActivity> get allActivities => _allActivities;
  List<CoachSession> get sessions => List.unmodifiable(_sessions);
  CoachSession? get latestSession =>
      _sessions.isNotEmpty ? _sessions.first : null;
  bool get isLoading => _isLoading;
  bool get isCreatingSession => _isCreatingSession;
  bool get hasLoadedRemote => _hasLoadedRemote;
  String? get error => _error;

  CoachProvider({required ApiClient client})
    : _repository = CoachRepository(client: client) {
    _loadLocalData();
  }

  Future<void> loadCoachData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _loadLocalData();

    try {
      _sessions = await _repository.getSessions();
      _hasLoadedRemote = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> requestGuidanceForActivity(CoachActivity activity) async {
    _isCreatingSession = true;
    _error = null;
    notifyListeners();

    final prompt =
        'Je veux faire cette activité bien-être: ${activity.title}. '
        'Aide-moi à la lancer concrètement en ${activity.durationMinutes} minutes.';

    try {
      final session = await _repository.createSession(
        prompt: prompt,
        context: {
          'activityId': activity.id,
          'category': activity.category.name,
          'durationMinutes': activity.durationMinutes,
        },
      );
      _sessions = [session, ..._sessions];
      _hasLoadedRemote = true;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isCreatingSession = false;
      notifyListeners();
    }
  }

  void _loadLocalData() {
    _todayAdvice = _repository.getAdviceForToday();
    _recommendedActivities = _repository.getRecommendedActivities();
    _allActivities = _repository.getAllActivities();
  }
}
