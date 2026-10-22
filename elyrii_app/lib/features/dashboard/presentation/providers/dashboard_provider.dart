import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/config/dev_session.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/models/dashboard_models.dart';
import '../../domain/civil_day.dart';
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

  // Historique typé pour le calendrier : un point par jour connu du serveur.
  final Map<CivilDay, ActivityTimelinePoint> _history = {};
  late final Map<CivilDay, ActivityTimelinePoint> _historyView =
      UnmodifiableMapView(_history);
  CalendarCoverage? _coverage;
  int _widestDays = 30;

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

  /// Historique serveur indexé par jour, couvrant `coverage` au plus.
  Map<CivilDay, ActivityTimelinePoint> get history => _historyView;

  /// Plage réellement chargée ; null avant le premier chargement. Un jour
  /// hors plage est inconnu, jamais absent.
  CalendarCoverage? get coverage => _coverage;

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
    _loadInFlightDays = 0;
    _queuedDays = 0;
    _selectedMood = null;
    _moodVersion++;
    _isSavingMood = false;
    _cachedAt = null;
    _currentStreak = 0;
    _history.clear();
    _coverage = null;
    _widestDays = 30;
    _isLoading = false;
    _error = null;
    _notify();
  }

  void onUserChanged({String? userId, bool isDemo = false}) {
    resetSession();
    _repository.onUserChanged(userId: userId, isDemo: isDemo);
  }

  void _applyDevStats(int days) {
    _applyStats(
      DashboardStats.fromJson(
        DevSession.statsPayload(now: _now(), rangeDays: days),
      ),
    );
    _error = null;
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
  int _loadInFlightDays = 0;
  int _queuedDays = 0;

  /// Recharge toujours la plage la plus large déjà demandée : un
  /// rafraîchissement doit atteindre le réseau, la couverture ne le
  /// court-circuite pas.
  Future<void> loadDashboardData() => _startLoad(_widestDays);

  /// Garantit un historique couvrant [month] : la plage demandée va du
  /// premier jour du mois à aujourd'hui, plafonnée aux 365 jours acceptés
  /// par l'API existante. Une plage déjà couverte ne déclenche rien.
  Future<void> ensureCalendarHistory(CivilMonth month) {
    final today = CivilDay.fromLocal(_now());
    final span = month.firstDay.isAfter(today)
        ? 30
        : month.firstDay.daysUntil(today) + 1;
    final days = span.clamp(30, 365);
    if (days > _widestDays) _widestDays = days;
    if (_coversDays(days)) return Future.value();
    return _startLoad(days);
  }

  bool _coversDays(int days) {
    final coverage = _coverage;
    if (coverage == null) return false;
    final today = CivilDay.fromLocal(_now());
    return !coverage.firstDay.isAfter(today.addDays(-(days - 1))) &&
        !coverage.throughDay.isBefore(today);
  }

  Future<void> _startLoad(int days) {
    final inFlight = _loadInFlight;
    if (inFlight != null) {
      // La queue termine la plage la plus large demandée, sans deux
      // requêtes simultanées du même provider.
      if (days > _loadInFlightDays && days > _queuedDays) _queuedDays = days;
      return inFlight;
    }
    late final Future<void> future;
    future = _runLoad(days).whenComplete(() {
      if (identical(_loadInFlight, future)) _loadInFlight = null;
    });
    _loadInFlight = future;
    return future;
  }

  Future<void> _runLoad(int days) async {
    var rangeDays = days;
    while (true) {
      _loadInFlightDays = rangeDays;
      try {
        await _loadDashboardData(rangeDays);
      } finally {
        _loadInFlightDays = 0;
      }
      final queued = _queuedDays;
      _queuedDays = 0;
      if (queued <= rangeDays || _coversDays(queued)) return;
      rangeDays = queued;
    }
  }

  Future<void> _loadDashboardData(int days) async {
    if (_isDemo) {
      _applyDevStats(days);
      return;
    }
    final range = '${days}d';
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
        final cached = await _repository.getCachedDashboard(range: range);
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
      final data = await _repository.getDashboard(range: range);
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
    _applyStats(data.stats, fetchedAt: data.cachedAt);
  }

  void _applyStats(DashboardStats stats, {DateTime? fetchedAt}) {
    _currentStreak = stats.streak;
    _history
      ..clear()
      ..addEntries(
        stats.activityTimeline.map((point) => MapEntry(point.day, point)),
      );
    // La couverture est calculée côté client, depuis la plage demandée
    // jusqu'au jour de récupération : le serveur ne déclare pas ses bornes.
    final through = CivilDay.fromLocal(fetchedAt ?? _now());
    _coverage = CalendarCoverage(
      firstDay: through.addDays(-(stats.rangeDays - 1)),
      throughDay: through,
    );
    _isLoading = false;
    _notify();
  }

  Future<void> refresh() async {
    await loadDashboardData();
  }
}
