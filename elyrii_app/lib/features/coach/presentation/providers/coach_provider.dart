import 'package:flutter/material.dart';
import '../../data/models/coach_model.dart';
import '../../data/repositories/coach_repository.dart';

class CoachProvider extends ChangeNotifier {
  final CoachRepository _repository = CoachRepository();

  DailyAdvice? _todayAdvice;
  List<CoachActivity> _recommendedActivities = [];
  List<CoachActivity> _allActivities = [];
  bool _isLoading = false;

  DailyAdvice? get todayAdvice => _todayAdvice;
  List<CoachActivity> get recommendedActivities => _recommendedActivities;
  List<CoachActivity> get allActivities => _allActivities;
  bool get isLoading => _isLoading;

  CoachProvider() {
    loadCoachData();
  }

  void loadCoachData() {
    _isLoading = true;
    notifyListeners();

    _todayAdvice = _repository.getAdviceForToday();
    _recommendedActivities = _repository.getRecommendedActivities();
    _allActivities = _repository.getAllActivities();

    _isLoading = false;
    notifyListeners();
  }
}
