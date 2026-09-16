import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math';
import '../../../../core/network/api_client.dart';
import '../../data/repositories/dashboard_repository.dart';

/// Enum représentant les différents moods disponibles
enum MoodType { verySad, sad, neutral, happy, veryHappy }

/// Enum pour les types d'objectifs quotidiens
enum GoalType { journal, meditation, breathing, gratitude }

/// Extension pour obtenir les propriétés du mood
extension MoodTypeExtension on MoodType {
  IconData get icon {
    switch (this) {
      case MoodType.verySad:
        return Icons.sentiment_very_dissatisfied_rounded;
      case MoodType.sad:
        return Icons.sentiment_dissatisfied_rounded;
      case MoodType.neutral:
        return Icons.sentiment_neutral_rounded;
      case MoodType.happy:
        return Icons.sentiment_satisfied_rounded;
      case MoodType.veryHappy:
        return Icons.sentiment_very_satisfied_rounded;
    }
  }

  Color get color {
    switch (this) {
      case MoodType.verySad:
        return const Color(0xFF6B7FA3); // Ardoise apaisante
      case MoodType.sad:
        return const Color(0xFF7E94B3); // Bleu brumeux
      case MoodType.neutral:
        return const Color(0xFF8E959E); // Sauge / pierre calme
      case MoodType.happy:
        return const Color(0xFF5BA87E); // Vert clarté & sérénité
      case MoodType.veryHappy:
        return const Color(0xFFE5A038); // Ambre doré & rayonnement
    }
  }

  String get label {
    switch (this) {
      case MoodType.verySad:
        return 'Éprouvé';
      case MoodType.sad:
        return 'Vulnérable';
      case MoodType.neutral:
        return 'Paisible';
      case MoodType.happy:
        return 'Serein';
      case MoodType.veryHappy:
        return 'Rayonnant';
    }
  }

  String get subtitle {
    switch (this) {
      case MoodType.verySad:
        return 'Besoin de douceur et de repos';
      case MoodType.sad:
        return 'Une baisse d\'énergie passagère';
      case MoodType.neutral:
        return 'Calme, présent, à ton rythme';
      case MoodType.happy:
        return 'Une belle clarté d\'esprit';
      case MoodType.veryHappy:
        return 'Plein d\'élan et de gratitude';
    }
  }

  String get suggestedActionLabel {
    switch (this) {
      case MoodType.verySad:
        return '2 min de respiration apaisante';
      case MoodType.sad:
        return 'Déposer mes pensées dans le journal';
      case MoodType.neutral:
        return 'Prendre un instant de pause';
      case MoodType.happy:
        return 'Noter ce qui m\'a fait sourire';
      case MoodType.veryHappy:
        return 'Ancrer ce moment dans mon journal';
    }
  }

  IconData get suggestedActionIcon {
    switch (this) {
      case MoodType.verySad:
        return Icons.air_rounded;
      case MoodType.sad:
        return Icons.edit_note_rounded;
      case MoodType.neutral:
        return Icons.self_improvement_rounded;
      case MoodType.happy:
        return Icons.auto_awesome_rounded;
      case MoodType.veryHappy:
        return Icons.stars_rounded;
    }
  }

  String get suggestedActionRoute {
    switch (this) {
      case MoodType.verySad:
        return '/meditation';
      case MoodType.sad:
        return '/journal';
      case MoodType.neutral:
        return '/meditation';
      case MoodType.happy:
        return '/journal';
      case MoodType.veryHappy:
        return '/journal';
    }
  }
}

/// Extension pour les propriétés des objectifs
extension GoalTypeExtension on GoalType {
  String get title {
    switch (this) {
      case GoalType.journal:
        return 'Écrire dans ton journal';
      case GoalType.meditation:
        return '5 minutes de méditation';
      case GoalType.breathing:
        return 'Exercice de respiration';
      case GoalType.gratitude:
        return 'Noter 3 gratitudes';
    }
  }

  IconData get icon {
    switch (this) {
      case GoalType.journal:
        return Icons.edit_note_rounded;
      case GoalType.meditation:
        return Icons.self_improvement_rounded;
      case GoalType.breathing:
        return Icons.air_rounded;
      case GoalType.gratitude:
        return Icons.favorite_rounded;
    }
  }

  String get completedMessage {
    switch (this) {
      case GoalType.journal:
        return 'Bravo ! Tu as pris le temps d\'écrire';
      case GoalType.meditation:
        return 'Magnifique ! Ton esprit te remercie';
      case GoalType.breathing:
        return 'Super ! Tu respires la sérénité';
      case GoalType.gratitude:
        return 'Génial ! La gratitude illumine ta journée';
    }
  }
}

/// Provider pour gérer l'état du dashboard
class DashboardProvider extends ChangeNotifier {
  final DashboardRepository _repository;
  bool _isLoading = false;
  String? _error;

  // Mood du jour
  MoodType? _selectedMood;
  final Map<DateTime, MoodType> _moodHistory = {};

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
  Map<DateTime, MoodType> get moodHistory => Map.unmodifiable(_moodHistory);
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

  DashboardProvider({DashboardRepository? repository, ApiClient? apiClient})
    : assert(
        repository != null || apiClient != null,
        'repository or apiClient must be provided',
      ),
      _repository = repository ?? DashboardRepository(client: apiClient!) {
    _initializeQuoteOfTheDay();
    _initializeDailyGoal();
    _initializeMascotMessage();
  }

  void _initializeQuoteOfTheDay() {
    final now = DateTime.now();
    _currentQuoteIndex = (now.day + now.month) % _quotes.length;
  }

  void _initializeDailyGoal() {
    final now = DateTime.now();
    final goalIndex = (now.day + now.month + now.year) % GoalType.values.length;
    _dailyGoal = GoalType.values[goalIndex];
  }

  void _initializeMascotMessage() {
    final now = DateTime.now();
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
    notifyListeners();
  }

  Future<void> selectMood(MoodType mood) async {
    if (_selectedMood == mood) return;

    _selectedMood = mood;
    _currentMascotMessageIndex = Random().nextInt(
      _moodMascotMessages[mood]!.length,
    );
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    _moodHistory[today] = mood;
    _error = null;
    notifyListeners(); // Mise à jour optimiste immédiate (sans flash de squelette)

    // Synchronisation en arrière-plan sans bloquer l'UI ni recharger l'état de chargement
    unawaited(() async {
      try {
        await _repository.logMood(mood.name);
        final data = await _repository.getDashboard();
        final stats = data.stats;
        _currentStreak = stats.streak;
        _activeChallengesCount = stats.activeChallengesCount;
        _journalEntriesCount = stats.journalEntriesCount;
        _completedChallengesCount = stats.completedChallengesCount;
        _totalPoints = stats.totalPoints;
        _meditationSessionsCount = stats.meditationSessionsCount;
        _coachSessionsCount = stats.coachSessionsCount;
        _moodLogsCount = stats.moodLogsCount;
        notifyListeners();
      } catch (_) {
        // En mode déconnecté, préserve silencieusement la saisie locale
      }
    }());
  }

  void completeGoal() {
    _goalCompleted = true;
    notifyListeners();
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
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

  Future<void> loadDashboardData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _repository.getDashboard();
      final moodTypeStr = data.latestMood;
      if (moodTypeStr != null) {
        _selectedMood = MoodType.values.firstWhere(
          (m) => m.name == moodTypeStr,
          orElse: () => MoodType.neutral,
        );
      } else {
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
      notifyListeners();
    } catch (_) {
      // Mode silencieux : n'affiche pas d'exception socket brute sur l'accueil
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadDashboardData();
  }

  void setUserName(String name) {
    _userName = name;
    notifyListeners();
  }
}
