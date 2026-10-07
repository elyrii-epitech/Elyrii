import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import 'dart:math';

import '../../../../core/config/dev_session.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/repositories/dashboard_repository.dart';

import '../mood_presentation.dart';
export '../mood_presentation.dart';

/// Provider pour gérer l'état du dashboard
class DashboardProvider extends ChangeNotifier {
  final DashboardRepository _repository;
  final bool Function()? _isDemoSession;
  int _sessionRevision = 0;
  bool _disposed = false;

  bool get _isDemo => _isDemoSession?.call() == true;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool _isLoading = false;
  bool _isSavingMood = false;
  DateTime? _cachedAt;
  final DateTime Function() _now;
  int _moodVersion = 0;
  String? _error;

  // Mood du jour
  MoodType? _selectedMood;
  final Map<DateTime, MoodType> _moodHistory = {};
  late final Map<DateTime, MoodType> _historyView = UnmodifiableMapView(
    _moodHistory,
  );

  // Streak (série de jours consécutifs)
  int _currentStreak = 0;
  int _activeChallengesCount = 0;
  int _journalEntriesCount = 0;
  int _completedChallengesCount = 0;
  int _totalPoints = 0;
  int _meditationSessionsCount = 0;
  int _coachSessionsCount = 0;
  int _moodLogsCount = 0;

  // Quote du jour
  int _currentQuoteIndex = 0;
  final List<String> _quotes = [
    "La patience est l'art d'espérer.",
    "Chaque jour est une nouvelle chance de changer ta vie.",
    "Le bonheur n'est pas une destination, c'est un voyage.",
    "Prends soin de toi, tu es la personne avec qui tu passeras le plus de temps.",
    "Les petits pas mènent aux grandes destinations.",
    "Respire. Tout va bien se passer.",
    "Tu es plus fort(e) que tu ne le penses.",
    "Aujourd'hui est un bon jour pour être heureux.",
  ];

  // Messages de la mascotte Elyrii
  int _currentMascotMessageIndex = 0;
  final List<String> _mascotMessages = [
    "Je suis contente de te voir",
    "Comment vas-tu aujourd'hui ?",
    "N'oublie pas : tu es incroyable !",
    "Prends un moment pour toi",
    "Je suis là si tu as besoin de parler",
    "Chaque petit pas compte",
    "Tu fais du super boulot !",
    "Respire profondément... voilà",
    "Ta présence ici est déjà une victoire",
    "Je crois en toi, toujours",
  ];

  // Messages adaptés au mood
  final Map<MoodType, List<String>> _moodMascotMessages = {
    MoodType.verySad: [
      "Je suis là pour toi, toujours",
      "C'est ok de ne pas aller bien...",
      "Veux-tu qu'on en parle ensemble ?",
      "Je t'envoie plein de douceur",
    ],
    MoodType.sad: [
      "Les nuages passent, le soleil revient",
      "Prends le temps qu'il te faut",
      "Courage, je suis là",
      "Demain sera un nouveau jour",
    ],
    MoodType.neutral: [
      "Une journée tranquille, c'est bien aussi",
      "Que dirais-tu d'un petit moment zen ?",
      "Parfois, neutre c'est parfait",
      "On avance à notre rythme",
    ],
    MoodType.happy: [
      "Ça fait plaisir de te voir sourire !",
      "Continue comme ça, tu gères !",
      "Ta bonne humeur est contagieuse",
      "Profite bien de cette belle énergie !",
    ],
    MoodType.veryHappy: [
      "Quelle belle énergie !",
      "Tu rayonnes aujourd'hui !",
      "J'adore te voir comme ça !",
      "Partage cette joie avec le monde !",
    ],
  };

  // Objectif du jour
  GoalType _dailyGoal = GoalType.journal;
  bool _goalCompleted = false;

  // Nom utilisateur (à récupérer depuis l'auth plus tard)
  String _userName = '';

  // Getters
  bool get isSavingMood => _isSavingMood;
  DateTime? get cachedAt => _cachedAt;
  bool get isLoading => _isLoading;
  String? get error => _error;
  MoodType? get selectedMood => _selectedMood;
  int get currentStreak => _currentStreak;
  int get activeChallengesCount => _activeChallengesCount;
  int get journalEntriesCount => _journalEntriesCount;
  int get completedChallengesCount => _completedChallengesCount;
  int get totalPoints => _totalPoints;
  int get meditationSessionsCount => _meditationSessionsCount;
  int get coachSessionsCount => _coachSessionsCount;
  int get moodLogsCount => _moodLogsCount;
  String get userName => _userName;
  String get currentQuote => _quotes[_currentQuoteIndex];
  Map<DateTime, MoodType> get moodHistory => _historyView;
  GoalType get dailyGoal => _dailyGoal;
  bool get goalCompleted => _goalCompleted;

  /// Retourne le message actuel de la mascotte
  String get mascotMessage {
    if (_selectedMood != null) {
      final messages = _moodMascotMessages[_selectedMood]!;
      return messages[_currentMascotMessageIndex % messages.length];
    }
    return _mascotMessages[_currentMascotMessageIndex % _mascotMessages.length];
  }

  DashboardProvider({
    DashboardRepository? repository,
    ApiClient? apiClient,
    this._isDemoSession,
    DateTime Function()? now,
  }) : assert(
         repository != null || apiClient != null,
         'repository or apiClient must be provided',
       ),
       _repository = repository ?? DashboardRepository(client: apiClient!),
       _now = now ?? DateTime.now {
    _initializeQuoteOfTheDay();
    _initializeDailyGoal();
    _initializeMascotMessage();
  }

  void resetSession() {
    _sessionRevision++;
    _loadInFlight = null;
    _selectedMood = null;
    _moodVersion++;
    _isSavingMood = false;
    _cachedAt = null;
    _moodHistory.clear();
    _currentStreak = 0;
    _activeChallengesCount = 0;
    _journalEntriesCount = 0;
    _completedChallengesCount = 0;
    _totalPoints = 0;
    _meditationSessionsCount = 0;
    _coachSessionsCount = 0;
    _moodLogsCount = 0;
    _goalCompleted = false;
    _userName = '';
    _isLoading = false;
    _error = null;
    _notify();
  }

  void onUserChanged({String? userId, bool isDemo = false}) {
    resetSession();
    _repository.onUserChanged(userId: userId, isDemo: isDemo);
  }

  void _applyDevStats() {
    _currentStreak = DevSession.streakDays;
    _completedChallengesCount = DevSession.completedChallengeCount;
    _totalPoints = DevSession.totalPoints;
    _userName = DevSession.firstName;
    _isLoading = false;
    _error = null;
    _notify();
  }

  void _initializeQuoteOfTheDay() {
    final now = _now();
    _currentQuoteIndex = (now.day + now.month) % _quotes.length;
  }

  void _initializeDailyGoal() {
    final now = _now();
    final goalIndex = (now.day + now.month + now.year) % GoalType.values.length;
    _dailyGoal = GoalType.values[goalIndex];
  }

  void _initializeMascotMessage() {
    final now = _now();
    _currentMascotMessageIndex =
        (now.hour + now.minute) % _mascotMessages.length;
  }

  void nextMascotMessage() {
    if (_selectedMood != null) {
      final messages = _moodMascotMessages[_selectedMood]!;
      _currentMascotMessageIndex =
          (_currentMascotMessageIndex + 1) % messages.length;
    } else {
      _currentMascotMessageIndex =
          (_currentMascotMessageIndex + 1) % _mascotMessages.length;
    }
    _notify();
  }

  Future<bool> selectMood(MoodType mood) async {
    if (_selectedMood == mood || _isSavingMood || _disposed) return false;
    final session = _sessionRevision;
    _moodVersion++;
    final previous = _selectedMood;
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final previousHistory = _moodHistory[today];
    _selectedMood = mood;
    _moodHistory[today] = mood;
    _currentMascotMessageIndex = Random().nextInt(
      _moodMascotMessages[mood]!.length,
    );
    _error = null;
    _isSavingMood = !_isDemo;
    _notify();
    if (_isDemo) return true;
    try {
      await _repository.logMood(mood.name);
      if (session != _sessionRevision || _disposed) return false;
      _isSavingMood = false;
      _notify();
      // A refresh failure does not undo an already acknowledged mutation.
      await loadDashboardData();
      return true;
    } catch (error) {
      if (session != _sessionRevision || _disposed) return false;
      _selectedMood = previous;
      if (previousHistory == null) {
        _moodHistory.remove(today);
      } else {
        _moodHistory[today] = previousHistory;
      }
      _error = error is ApiException
          ? error.message
          : 'Ton humeur n’a pas été enregistrée. Réessaie.';
      return false;
    } finally {
      if (session == _sessionRevision && !_disposed) {
        _isSavingMood = false;
        _notify();
      }
    }
  }

  void completeGoal() {
    _goalCompleted = true;
    _notify();
  }

  String getGreeting() {
    final hour = _now().hour;
    if (hour < 12) {
      return 'Bonjour';
    } else if (hour < 18) {
      return 'Bon après-midi';
    } else {
      return 'Bonsoir';
    }
  }

  String getMoodMessage() {
    if (_selectedMood == null) {
      return 'Comment te sens-tu aujourd\'hui ?';
    }
    switch (_selectedMood!) {
      case MoodType.verySad:
        return 'Je suis là pour toi. Veux-tu en parler ?';
      case MoodType.sad:
        return 'Les jours difficiles passent aussi.';
      case MoodType.neutral:
        return 'Une journée tranquille, c\'est bien aussi.';
      case MoodType.happy:
        return 'Super ! Continue sur cette lancée !';
      case MoodType.veryHappy:
        return 'Quelle belle énergie !';
    }
  }

  Future<void>? _loadInFlight;

  Future<void> loadDashboardData() {
    if (_loadInFlight != null) return _loadInFlight!;
    late final Future<void> future;
    future = _loadDashboardData().whenComplete(() {
      if (identical(_loadInFlight, future)) _loadInFlight = null;
    });
    _loadInFlight = future;
    return future;
  }

  Future<void> _loadDashboardData() async {
    if (_isDemo) {
      _applyDevStats();
      return;
    }
    final session = _sessionRevision;
    final moodVersion = _moodVersion;
    _isLoading = true;
    _error = null;
    _notify();

    try {
      final data = await _repository.getDashboard();
      if (session != _sessionRevision) return;
      final moodTypeStr = data.latestMood;
      _cachedAt = data.cachedAt;
      if (moodVersion == _moodVersion && moodTypeStr != null) {
        _selectedMood = MoodType.values.firstWhere(
          (m) => m.name == moodTypeStr,
          orElse: () => MoodType.neutral,
        );
      } else if (moodVersion == _moodVersion) {
        _selectedMood = null;
      }

      final stats = data.stats;
      _currentStreak = stats.streak;
      _activeChallengesCount = stats.activeChallengesCount;
      _journalEntriesCount = stats.journalEntriesCount;
      _completedChallengesCount = stats.completedChallengesCount;
      _totalPoints = stats.totalPoints;
      _meditationSessionsCount = stats.meditationSessionsCount;
      _coachSessionsCount = stats.coachSessionsCount;
      _moodLogsCount = stats.moodLogsCount;
      _isLoading = false;
      _notify();
    } catch (error) {
      if (session != _sessionRevision) return;
      _error = error is ApiException
          ? error.message
          : 'Impossible de charger ton tableau de bord. Réessaie.';
      // Mode silencieux : n'affiche pas d'exception socket brute sur l'accueil
      _isLoading = false;
      _notify();
    }
  }

  Future<void> refresh() async {
    await loadDashboardData();
  }

  void setUserName(String name) {
    _userName = name;
    _notify();
  }
}
