import 'dart:async';

import 'package:flutter/material.dart';

import 'dart:math';

import '../../../../core/config/dev_session.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/models/dashboard_models.dart';

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

  // Streak (série de jours consécutifs)
  int _currentStreak = 0;

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

  // Getters
  bool get isSavingMood => _isSavingMood;
  DateTime? get cachedAt => _cachedAt;
  bool get isLoading => _isLoading;
  String? get error => _error;
  MoodType? get selectedMood => _selectedMood;
  int get currentStreak => _currentStreak;

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
    _initializeMascotMessage();
  }

  void resetSession() {
    _sessionRevision++;
    _loadInFlight = null;
    _selectedMood = null;
    _moodVersion++;
    _isSavingMood = false;
    _cachedAt = null;
    _currentStreak = 0;
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
    _isLoading = false;
    _error = null;
    _notify();
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
    _selectedMood = mood;
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

    var networkFinished = false;
    // Cached content and the refresh race independently. A slow cache must
    // never hold up a faster network result or replace fresher data afterward.
    unawaited(() async {
      try {
        final cached = await _repository.getCachedDashboard();
        if (_disposed ||
            session != _sessionRevision ||
            networkFinished ||
            cached == null) {
          return;
        }
        _applyDashboardData(cached, moodVersion);
      } catch (_) {
        // Cache failures do not cancel the network request or hide its errors.
      }
    }());
    try {
      final data = await _repository.getDashboard();
      networkFinished = true;
      if (_disposed || session != _sessionRevision) return;
      _applyDashboardData(data, moodVersion);
    } catch (error) {
      networkFinished = true;
      if (_disposed || session != _sessionRevision) return;
      _error = error is ApiException
          ? error.message
          : 'Impossible de charger ton tableau de bord. Réessaie.';
      // Mode silencieux : n'affiche pas d'exception socket brute sur l'accueil
      _isLoading = false;
      _notify();
    }
  }

  void _applyDashboardData(DashboardData data, int moodVersion) {
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
    _currentStreak = data.stats.streak;
    _isLoading = false;
    _notify();
  }

  Future<void> refresh() async {
    await loadDashboardData();
  }
}
