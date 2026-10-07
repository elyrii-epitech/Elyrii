import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';

import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../data/models/coach_model.dart';
import '../../data/repositories/coach_repository.dart';

/// Messages qu'Elyrii fait défiler dans sa bulle sur la page Coach.
/// Ton chaleureux et adulte : accompagnement, jamais d'infantilisation.
const List<String> kCoachMascotLines = [
  'Qu\'est-ce qui te ferait du bien, là, maintenant ?',
  'Un petit pas suffit. Je t\'accompagne.',
  'Tu n\'as pas besoin d\'y arriver parfaitement.',
  'Ton avancée d\'hier compte encore aujourd\'hui.',
  'Respirer ensemble trois minutes, ça change une journée.',
  'Je suis là, à ton rythme.',
];

class CoachProvider extends ChangeNotifier {
  final CoachRepository _repository;

  DailyAdvice? _todayAdvice;
  List<CoachActivity> _recommendedActivities = [];
  List<CoachActivity> _allActivities = [];
  List<CoachSession> _sessions = [];
  bool _isLoading = false;
  bool _isCreatingSession = false;
  bool _hasLoadedRemote = false;
  String? _owner;
  int _session = 0;
  bool _disposed = false;
  String? _error;
  Future<void>? _loadFuture;
  String? get error => _error;
  bool _current(int session) => !_disposed && session == _session;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  void onUserChanged({String? userId, bool isDemo = false}) {
    final owner = isDemo ? 'demo-user' : userId;
    if (_owner == owner) return;
    _owner = owner;
    _session++;
    _sessions = [];
    _selectedNeed = null;
    _mascotMessage = kCoachMascotLines.first;
    _isLoading = false;
    _isCreatingSession = false;
    _hasLoadedRemote = false;
    _error = null;
    _loadFuture = null;
    _loadLocalData();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _session++;
    super.dispose();
  }

  /// Besoin immédiat sélectionné par l'utilisateur (null = sélection par
  /// défaut du coach). Pilote la section recommandée et le message de la
  /// bulle.
  CoachNeed? _selectedNeed;

  /// Message courant de la bulle d'Elyrii : rotation manuelle au tap,
  /// remplacement contextuel quand un besoin est sélectionné.
  String _mascotMessage = kCoachMascotLines.first;

  DailyAdvice? get todayAdvice => _todayAdvice;
  List<CoachActivity> get recommendedActivities => _recommendedActivities;
  List<CoachActivity> get allActivities => _allActivities;
  List<CoachSession> get sessions => UnmodifiableListView(_sessions);
  CoachSession? get latestSession =>
      _sessions.isNotEmpty ? _sessions.first : null;
  bool get isLoading => _isLoading;
  bool get isCreatingSession => _isCreatingSession;
  bool get hasLoadedRemote => _hasLoadedRemote;
  CoachNeed? get selectedNeed => _selectedNeed;
  String get mascotMessage => _mascotMessage;

  /// Activités mises en avant : filtrées par le besoin sélectionné, sinon la
  /// sélection curatée du coach.
  List<CoachActivity> get highlightedActivities => _selectedNeed == null
      ? _recommendedActivities
      : _repository.getActivitiesForNeed(_selectedNeed!);

  CoachProvider({CoachRepository? repository, ApiClient? client})
    : assert(
        repository != null || client != null,
        'repository or client must be provided',
      ),
      _repository = repository ?? CoachRepository(client: client!) {
    _loadLocalData();
  }

  /// Sélectionne (ou désactive avec null) le besoin immédiat.
  /// La bulle d'Elyrii répond au contexte du besoin.
  void selectNeed(CoachNeed? need) {
    if (_selectedNeed == need) return;
    _selectedNeed = need;
    _mascotMessage = need?.bubbleMessage ?? kCoachMascotLines.first;
    notifyListeners();
  }

  /// Fait défiler les messages de la bulle (tap sur la mascotte ou la bulle).
  void nextMascotMessage() {
    final index = kCoachMascotLines.indexOf(_mascotMessage);
    final next = kCoachMascotLines[(index + 1) % kCoachMascotLines.length];
    if (next == _mascotMessage) return;
    _mascotMessage = next;
    notifyListeners();
  }

  /// Message contextuel ponctuel (succès d'une guidance, retour d'expérience).
  void setMascotMessage(String message) {
    if (_mascotMessage == message) return;
    _mascotMessage = message;
    notifyListeners();
  }

  Future<void> loadCoachData() {
    if (_loadFuture != null) return _loadFuture!;
    late final Future<void> request;
    request = _loadCoachData().whenComplete(() {
      if (identical(_loadFuture, request)) _loadFuture = null;
    });
    return _loadFuture = request;
  }

  Future<void> _loadCoachData() async {
    final revision = _session;
    _isLoading = true;
    notifyListeners();

    _loadLocalData();

    try {
      final sessions = await _repository.getSessions();
      if (_current(revision)) _sessions = sessions;
    } catch (e) {
      // Frontend d'abord : sans backend, la page reste pleinement utilisable.
      if (_current(revision)) _error = 'Impossible de charger les séances.';
    } finally {
      if (_current(revision)) {
        _hasLoadedRemote = true;
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Demande une guidance pour une activité.
  ///
  /// Le contenu IA n'est pas encore défini côté backend : en attendant, un
  /// placeholder local honnête (marqué `placeholder` dans le contexte) fait
  /// vivre le parcours complet. Dès que le backend répond, la vraie réponse
  /// prend sa place sans changer l'interface.
  Future<bool> requestGuidanceForActivity(CoachActivity activity) async {
    if (_isCreatingSession) return false;
    final revision = _session;
    _error = null;
    _isCreatingSession = true;
    notifyListeners();

    final prompt =
        'Je veux faire cette activité bien-être: ${activity.title}. '
        'Aide-moi à la lancer concrètement en ${activity.durationMinutes} minutes.';

    final context = {
      'activityId': activity.id,
      'category': activity.category.name,
      'durationMinutes': activity.durationMinutes,
    };

    try {
      final session = await _repository.createSession(
        prompt: prompt,
        context: context,
      );
      if (!_current(revision)) return false;
      _sessions = [session, ..._sessions];
      _hasLoadedRemote = true;
      return true;
    } catch (e) {
      if (!_current(revision)) return false;
      if (e is FormatException || (e is ApiException && !e.canUseOfflineData)) {
        _error = e is ApiException ? e.message : 'Réponse du service invalide.';
        return false;
      }
      _sessions = [
        CoachSession(
          id: 'local-${DateTime.now().millisecondsSinceEpoch}',
          prompt: prompt,
          response: _repository.placeholderGuidanceFor(activity),
          context: {...context, 'placeholder': true},
          createdAt: DateTime.now(),
        ),
        ..._sessions,
      ];
      return true;
    } finally {
      if (_current(revision)) {
        _isCreatingSession = false;
        notifyListeners();
      }
    }
  }

  void _loadLocalData() {
    _todayAdvice = _repository.getAdviceForToday();
    _recommendedActivities = _repository.getRecommendedActivities();
    _allActivities = _repository.getAllActivities();
  }
}
