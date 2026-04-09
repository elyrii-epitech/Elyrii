import 'package:flutter/foundation.dart';
import 'dart:math';
import '../../../../core/network/api_client.dart';
import '../../../../core/config/api_config.dart';

/// Enum représentant les différents moods disponibles
enum MoodType { verySad, sad, neutral, happy, veryHappy }

/// Enum pour les types d'objectifs quotidiens
enum GoalType { journal, meditation, breathing, gratitude }

/// Extension pour obtenir les propriétés du mood
extension MoodTypeExtension on MoodType {
  String get emoji {
    switch (this) {
      case MoodType.verySad:
        return '😢';
      case MoodType.sad:
        return '😕';
      case MoodType.neutral:
        return '😐';
      case MoodType.happy:
        return '🙂';
      case MoodType.veryHappy:
        return '😊';
    }
  }

  String get label {
    switch (this) {
      case MoodType.verySad:
        return 'Très triste';
      case MoodType.sad:
        return 'Triste';
      case MoodType.neutral:
        return 'Neutre';
      case MoodType.happy:
        return 'Content';
      case MoodType.veryHappy:
        return 'Très content';
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

  String get emoji {
    switch (this) {
      case GoalType.journal:
        return '📝';
      case GoalType.meditation:
        return '🧘';
      case GoalType.breathing:
        return '🌬️';
      case GoalType.gratitude:
        return '🙏';
    }
  }

  String get completedMessage {
    switch (this) {
      case GoalType.journal:
        return 'Bravo ! Tu as pris le temps d\'écrire 💜';
      case GoalType.meditation:
        return 'Magnifique ! Ton esprit te remercie 🧘';
      case GoalType.breathing:
        return 'Super ! Tu respires la sérénité 🌬️';
      case GoalType.gratitude:
        return 'Génial ! La gratitude illumine ta journée ✨';
    }
  }
}

/// Provider pour gérer l'état du dashboard
class DashboardProvider extends ChangeNotifier {
  final ApiClient _apiClient;
  bool _isLoading = false;
  String? _error;

  // Mood du jour
  MoodType? _selectedMood;
  final Map<DateTime, MoodType> _moodHistory = {};

  // Streak (série de jours consécutifs)
  int _currentStreak = 12;

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
    "Coucou ! Je suis contente de te voir 💜",
    "Comment vas-tu aujourd'hui ?",
    "N'oublie pas : tu es incroyable !",
    "Prends un moment pour toi ✨",
    "Je suis là si tu as besoin de parler",
    "Chaque petit pas compte 🌱",
    "Tu fais du super boulot !",
    "Respire profondément... voilà 😊",
    "Ta présence ici est déjà une victoire",
    "Je crois en toi, toujours 💪",
  ];

  // Messages adaptés au mood
  final Map<MoodType, List<String>> _moodMascotMessages = {
    MoodType.verySad: [
      "Je suis là pour toi, toujours 💜",
      "C'est ok de ne pas aller bien...",
      "Veux-tu qu'on en parle ensemble ?",
      "Je t'envoie plein de douceur 🤗",
    ],
    MoodType.sad: [
      "Les nuages passent, le soleil revient ☀️",
      "Prends le temps qu'il te faut",
      "Un câlin virtuel pour toi 🤗",
      "Demain sera un nouveau jour",
    ],
    MoodType.neutral: [
      "Une journée tranquille, c'est bien aussi",
      "Que dirais-tu d'un petit moment zen ?",
      "Parfois, neutre c'est parfait 😌",
      "On avance à notre rythme",
    ],
    MoodType.happy: [
      "Ça fait plaisir de te voir sourire !",
      "Continue comme ça, tu gères ! 🌟",
      "Ta bonne humeur est contagieuse 😊",
      "Profite bien de cette belle énergie !",
    ],
    MoodType.veryHappy: [
      "Waouh ! Quelle belle énergie ! ✨",
      "Tu rayonnes aujourd'hui ! 🌟",
      "J'adore te voir comme ça ! 💜",
      "Partage cette joie avec le monde !",
    ],
  };

  // Objectif du jour
  GoalType _dailyGoal = GoalType.journal;
  bool _goalCompleted = false;

  // Nom utilisateur (à récupérer depuis l'auth plus tard)
  String _userName = 'Marie';

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  MoodType? get selectedMood => _selectedMood;
  int get currentStreak => _currentStreak;
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

  DashboardProvider({required ApiClient apiClient}) : _apiClient = apiClient {
    _initializeQuoteOfTheDay();
    _initializeDailyGoal();
    _initializeMascotMessage();
  }

  /// Initialise la quote du jour basée sur la date
  void _initializeQuoteOfTheDay() {
    final now = DateTime.now();
    _currentQuoteIndex = (now.day + now.month) % _quotes.length;
  }

  /// Initialise l'objectif du jour
  void _initializeDailyGoal() {
    final now = DateTime.now();
    final goalIndex = (now.day + now.month + now.year) % GoalType.values.length;
    _dailyGoal = GoalType.values[goalIndex];
  }

  /// Initialise le message de la mascotte
  void _initializeMascotMessage() {
    final now = DateTime.now();
    _currentMascotMessageIndex =
        (now.hour + now.minute) % _mascotMessages.length;
  }

  /// Change le message de la mascotte (pour le prochain)
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

  /// Sélectionne le mood du jour
  Future<void> selectMood(MoodType mood) async {
    _selectedMood = mood;

    // Réinitialiser l'index du message pour le nouveau mood
    _currentMascotMessageIndex = Random().nextInt(
      _moodMascotMessages[mood]!.length,
    );

    // Enregistrer dans l'historique
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    _moodHistory[today] = mood;

    // Incrémenter le streak si c'est la première fois aujourd'hui
    _updateStreak();

    notifyListeners();

    try {
      await _apiClient.post(
        ApiConfig.logMoodUrl,
        body: {'moodType': mood.name},
      );
    } catch (e) {
      _error = "Impossible d'enregistrer l'humeur: ${e.toString()}";
      notifyListeners();
    }
  }

  /// Marque l'objectif comme complété
  void completeGoal() {
    _goalCompleted = true;
    notifyListeners();
  }

  /// Met à jour le streak
  void _updateStreak() {
    // Logique simplifiée - dans une vraie app, vérifier les jours consécutifs
    _currentStreak++;
  }

  /// Retourne le message de salutation basé sur l'heure
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

  /// Retourne le message adapté au mood sélectionné
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
        return 'Quelle belle énergie ! 🌟';
    }
  }

  /// Charge les données du dashboard
  Future<void> loadDashboardData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiClient.get(ApiConfig.latestMoodUrl);
      final moodTypeStr = response['moodType'] as String?;
      
      if (moodTypeStr != null) {
        _selectedMood = MoodType.values.firstWhere(
          (m) => m.name == moodTypeStr,
          orElse: () => MoodType.neutral,
        );
      }

      // TODO: Call API for other stats

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Rafraîchit les données
  Future<void> refresh() async {
    await loadDashboardData();
  }

  /// Met à jour le nom d'utilisateur
  void setUserName(String name) {
    _userName = name;
    notifyListeners();
  }
}
