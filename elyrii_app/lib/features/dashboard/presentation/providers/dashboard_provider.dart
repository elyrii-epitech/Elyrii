import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import '../../../../core/config/dev_session.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/accueil_activities.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/models/dashboard_models.dart';
import '../../domain/civil_day.dart';
import '../mood_presentation.dart';
export '../mood_presentation.dart';

class DashboardProvider extends ChangeNotifier {
  final DashboardRepository _repository;
  AccueilActivities? _activities;
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

  // Getters
  bool get isSavingMood => _isSavingMood;
  DateTime? get cachedAt => _cachedAt;
  bool get isLoading => _isLoading;
  String? get error => _error;
  MoodType? get selectedMood => _selectedMood;
  int get currentStreak => _currentStreak;

  /// Server history indexed by day, covering at most `coverage`.
  Map<CivilDay, ActivityTimelinePoint> get history => _historyView;

  /// Actually loaded range; null before the first load. Days outside it are
  /// unknown, never absent.
  CalendarCoverage? get coverage => _coverage;

  DashboardProvider({
    DashboardRepository? repository,
    ApiClient? apiClient,
    AccueilActivities? activities,
    this._isDemoSession,
    DateTime Function()? now,
  }) : assert(
         repository != null || apiClient != null,
         'repository or apiClient must be provided',
       ),
       _repository = repository ?? DashboardRepository(client: apiClient!),
       _now = now ?? DateTime.now {
    _activities = activities;
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

  Future<bool> selectMood(MoodType mood) async {
    if (_selectedMood == mood || _isSavingMood || _disposed) return false;
    final session = _sessionRevision;
    _moodVersion++;
    final previous = _selectedMood;
    _selectedMood = mood;
    _error = null;
    _isSavingMood = !_isDemo;
    _notify();
    if (_isDemo) {
      _recordMoodLocally(mood);
      return true;
    }
    try {
      await _repository.logMood(mood.name);
      if (session != _sessionRevision || _disposed) return false;
      _isSavingMood = false;
      _notify();
      _recordMoodLocally(mood);
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

  /// The confirmed daily mood is also a local calendar fact; a local write
  /// failure does not undo the saved mood.
  void _recordMoodLocally(MoodType mood) {
    final activities = _activities;
    if (activities == null) return;
    unawaited(
      activities.recordMood(day: CivilDay.fromLocal(_now()), mood: mood),
    );
  }

  Future<void>? _loadInFlight;
  int _loadInFlightDays = 0;
  int _queuedDays = 0;

  /// Always reloads the widest range already requested. Refresh must reach the
  /// network rather than being short-circuited by coverage.
  Future<void> loadDashboardData() => _startLoad(_widestDays);

  /// Ensures history covers [month], requesting from the month's first day
  /// through today, capped at the existing API's 365-day limit. Already covered
  /// ranges trigger nothing.
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
