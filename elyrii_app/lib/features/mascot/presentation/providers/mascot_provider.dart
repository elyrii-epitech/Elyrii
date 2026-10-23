import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/config/mascot_animations.dart';
import '../../../../core/config/mascot_themes.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/mascot_accessory.dart';
import '../../data/models/mascot_appearance.dart';
import '../../data/models/mascot_model.dart';
import '../../data/repositories/mascot_repository.dart';

/// Provider gérant l'état et l'interaction avec la mascotte 3D.
///
/// Permet de contrôler le modèle 3D globalement, gérer les thèmes visuels
/// (palettes des matériaux), les pièces 3D de sa garde-robe et les
/// animations.
class MascotProvider extends ChangeNotifier {
  String? _userId;
  bool _isDemo;
  bool _sessionBound;
  int _sessionRevision = 0;
  Future<void>? _loadFuture;

  String get storageScope => _isDemo ? 'demo' : _userId ?? 'guest';
  int get sessionRevision => _sessionRevision;
  bool get _needsSync => _userId != null && !_isDemo;
  bool get _canSync => _repository.canSync && _needsSync;
  final MascotRepository _repository;
  final Set<Future<void>> _loadingOperations = {};

  Future<void> get flushed async {
    await Future.wait(_loadingOperations.toList());
    await Future.wait([_persistTail, _syncTail]);
  }

  Future<void> _trackLoad(Future<void> operation) {
    late final Future<void> tracked;
    tracked = operation.whenComplete(() => _loadingOperations.remove(tracked));
    _loadingOperations.add(tracked);
    return tracked;
  }

  MascotModel _mascot = MascotModel.defaultMascot();
  Future<void> _syncTail = Future<void>.value();
  Future<void> _persistTail = Future<void>.value();
  bool _disposed = false;
  int _syncRevision = 0;
  bool _pendingSync = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool _hasGreeted = false;

  // Réactions transversales déclenchées par les autres parcours (journal,
  // jardin, coach…). Le widget de mascotte visible les consomme avec un
  // compteur plutôt qu'en comparant des objets, ce qui permet de rejouer le
  // même clip à chaque nouvel événement.
  MascotAnimation _reaction = MascotAnimations.idle;
  int _reactionTrigger = 0;
  String? _lastReactionKey;

  /// Le salut d'arrivée est consommé une fois pour la vie de ce provider.
  bool takeGreeting() {
    if (_hasGreeted) return false;
    _hasGreeted = true;
    return true;
  }

  MascotAnimation get reaction => _reaction;
  int get reactionTrigger => _reactionTrigger;

  /// Publie une réaction courte à afficher sur la mascotte persistante.
  ///
  /// [eventKey] est utile pour les notifications provenant d'un flux qui peut
  /// émettre plusieurs fois le même état (par exemple un rafraîchissement
  /// réseau). Les interactions directes omettent la clé pour toujours rejouer
  /// le geste.
  void react(MascotAnimation animation, {String? eventKey}) {
    if (eventKey != null && eventKey == _lastReactionKey) return;
    _lastReactionKey = eventKey;
    _reaction = animation;
    _reactionTrigger++;
    _notify();
  }

  bool _isLoading = false;
  bool _isSyncing = false;
  String? _error;

  MascotProvider({
    ApiClient? client,
    MascotRepository? repository,
    String? userId,
    bool isDemo = false,
  }) : _repository = repository ?? MascotRepository(client: client),
       _userId = userId,
       _isDemo = isDemo,
       _sessionBound = userId != null || isDemo {
    unawaited(_trackLoad(_loadSavedMascot(_sessionRevision)));
  }

  /// Account-scoped persistence adapted from Lucas's studio. Changing scope
  /// invalidates old reads and queued syncs before loading the new account.
  Future<void> onUserChanged({
    String? userId,
    bool isDemo = false,
    bool migrateLegacy = false,
  }) async {
    if (_sessionBound && _userId == userId && _isDemo == isDemo) {
      await _loadFuture;
      return;
    }
    _changeSession(userId, isDemo);
    final session = _sessionRevision;
    late final Future<void> future;
    future =
        _trackLoad(() async {
          if (migrateLegacy && userId != null && !isDemo) {
            await _migrateLegacy(session);
          }
          if (session == _sessionRevision) await _loadMascot(session);
        }()).whenComplete(() {
          if (identical(_loadFuture, future)) _loadFuture = null;
        });
    _loadFuture = future;
    await future;
  }

  void _changeSession(String? userId, bool isDemo) {
    _userId = userId;
    _isDemo = isDemo;
    _sessionBound = true;
    _sessionRevision++;
    _syncRevision++;
    _loadFuture = null;
    _mascot = MascotModel.defaultMascot();
    _pendingSync = false;
    _isLoading = false;
    _isSyncing = false;
    _error = null;
    _hasGreeted = false;
    _reaction = MascotAnimations.idle;
    _reactionTrigger = 0;
    _lastReactionKey = null;
    _notify();
  }

  void resetSession() {
    if (_sessionBound && _userId == null && !_isDemo) return;
    _changeSession(null, false);
  }

  Future<void> _migrateLegacy(int session) => _repository.migrateLegacy(
    storageScope,
    () => !_disposed && session == _sessionRevision,
  );

  MascotModel get mascot => _mascot;

  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get error => _error;

  MascotTheme get currentTheme => MascotThemes.getById(_mascot.themeId);

  /// Applique un thème visuel à la mascotte.
  ///
  /// Le thème recolore les matériaux du modèle 3D à la volée,
  /// sans nécessiter de nouveau fichier GLB.
  void setTheme(String themeId) {
    themeId = _validThemeId(themeId);
    if (_mascot.themeId == themeId && _mascot.appearance.colors.isEmpty) return;

    _mascot = _mascot.copyWith(
      themeId: themeId,
      appearance: MascotAppearance(finish: _mascot.appearance.finish),
    );
    _notify();
    unawaited(_persistAndSync());
  }

  /// Équipe une pièce connue et débloquée, en remplaçant celle de sa zone.
  /// Retoucher la pièce portée la retire ; une célébration peut demander
  /// une sélection idempotente avec [toggleIfEquipped] à false.
  /// La vérification est faite ici, même si l'interface affiche un verrou.
  bool equipCosmetic(
    String cosmeticId, {
    required int completedChallenges,
    bool toggleIfEquipped = true,
  }) {
    final accessory = MascotAccessories.byId(cosmeticId);
    if (accessory == null) return false;
    cosmeticId = accessory.id;
    final isEquipped = _mascot.equippedCosmetics.contains(cosmeticId);
    if (isEquipped && !toggleIfEquipped) return false;
    if (!isEquipped && !accessory.isUnlocked(completedChallenges)) return false;

    final next = _mascot.equippedCosmetics
        .where(
          (id) => MascotAccessories.byId(id)?.category != accessory.category,
        )
        .toList();
    if (!isEquipped) next.add(cosmeticId);
    _mascot = _mascot.copyWith(
      equippedCosmetics: MascotAccessories.sanitizeSelection(next),
    );
    _notify();
    unawaited(_persistAndSync());
    return true;
  }

  /// Commit a studio draft only after checking newly equipped rewards.
  /// Local persistence succeeds independently of an unavailable server.
  Future<bool> saveCustomization(
    MascotModel draft, {
    required int completedChallenges,
    int? expectedSessionRevision,
  }) async {
    if (expectedSessionRevision != null &&
        expectedSessionRevision != _sessionRevision) {
      return false;
    }
    final session = _sessionRevision;
    final selection = MascotAccessories.sanitizeSelection(
      draft.equippedCosmetics,
    );
    for (final id in selection) {
      if (!_mascot.equippedCosmetics.contains(id) &&
          !MascotAccessories.byId(id)!.isUnlocked(completedChallenges)) {
        _error = 'Cet accessoire n’est pas encore débloqué.';
        _notify();
        return false;
      }
    }
    final previous = _mascot;
    _mascot = draft.copyWith(
      themeId: _validThemeId(draft.themeId),
      equippedCosmetics: selection,
      appearance: MascotAppearance.fromJson(draft.appearance.toJson()),
    );
    _error = null;
    _notify();
    final saved = await _saveMascot(markForSync: true);
    if (session != _sessionRevision) return false;
    if (!saved) {
      _mascot = previous;
      _notify();
      return false;
    }
    unawaited(_syncToBackend());
    return true;
  }

  Future<void> retrySync() => _syncToBackend();

  /// Réinitialise l'état de la mascotte par défaut
  void resetToDefault() {
    _mascot = MascotModel.defaultMascot();
    _error = null;
    _notify();
    unawaited(_persistAndSync());
  }

  Future<void> _persistAndSync() async {
    final session = _sessionRevision;
    if (await _saveMascot(markForSync: true) && session == _sessionRevision) {
      await _syncToBackend();
    }
  }

  Future<void> loadMascot() {
    if (_loadFuture != null) return _loadFuture!;
    late final Future<void> future;
    future = _trackLoad(_loadMascot(_sessionRevision)).whenComplete(() {
      if (identical(_loadFuture, future)) _loadFuture = null;
    });
    _loadFuture = future;
    return future;
  }

  Future<void> _loadMascot(int session) async {
    _isLoading = true;
    _error = null;
    _notify();

    await _loadSavedMascot(session);
    if (_disposed || session != _sessionRevision) return;

    if (!_canSync) {
      _isLoading = false;
      _notify();
      return;
    }

    if (_pendingSync) {
      _isLoading = false;
      _notify();
      unawaited(_syncToBackend());
      return;
    }

    try {
      final localRevision = _syncRevision;
      final remote = await _repository.getRemote(_mascot);
      if (session != _sessionRevision ||
          _pendingSync ||
          localRevision != _syncRevision) {
        return;
      }
      _mascot = remote;
      await _saveMascot();
    } catch (e) {
      if (session == _sessionRevision) {
        _error = 'Ton look local reste disponible. La synchronisation sera réessayée.';
      }
    } finally {
      if (session == _sessionRevision) {
        _isLoading = false;
        _notify();
      }
    }
  }

  Future<void> _loadSavedMascot(int session) async {
    try {
      final saved = await _repository.readLocal(
        storageScope,
        needsSync: _needsSync,
        isCurrent: () => !_disposed && session == _sessionRevision,
      );
      if (_disposed || session != _sessionRevision || saved.model == null) {
        return;
      }
      _mascot = saved.model!;
      _pendingSync = saved.pending;
      _notify();
    } catch (_) {
      if (!_disposed && session == _sessionRevision) {
        _error = 'Ta personnalisation locale n’a pas pu être chargée.';
        _notify();
      }
    }
  }

  Future<bool> _saveMascot({bool markForSync = false}) {
    final snapshot = _mascot;
    final scope = storageScope;
    final session = _sessionRevision;
    final pending = markForSync && _needsSync;
    if (pending) _pendingSync = true;
    final save = _persistTail.then((_) async {
      try {
        await _repository.writeLocal(scope, snapshot, pending: pending);
        return true;
      } catch (e) {
        if (session == _sessionRevision) {
          _error = 'La personnalisation n’a pas pu être enregistrée. Réessaie.';
          _notify();
        }
        return false;
      }
    });
    _persistTail = save.then((_) {});
    return save;
  }

  Future<void> _syncToBackend() async {
    if (!_canSync) return;
    final snapshot = _mascot;
    final session = _sessionRevision;
    final scope = storageScope;
    final revision = ++_syncRevision;
    _isSyncing = true;
    _error = null;
    _notify();
    // Serialize writes: a slow previous look must not overwrite a newer one.
    _syncTail = _syncTail.then((_) async {
      if (session != _sessionRevision) return;
      try {
        await _repository.saveRemote(snapshot);
        if (session == _sessionRevision && revision == _syncRevision) {
          _pendingSync = false;
          await _repository.markSynced(scope);
        }
      } catch (e) {
        if (session == _sessionRevision && revision == _syncRevision) {
          _error =
              'Look enregistré sur cet appareil. Synchronisation à réessayer.';
        }
      } finally {
        if (session == _sessionRevision && revision == _syncRevision) {
          _isSyncing = false;
          _notify();
        }
      }
    });
    await _syncTail;
  }

  String _validThemeId(String themeId) {
    final exists = MascotThemes.all.any((theme) => theme.id == themeId);
    return exists ? themeId : 'nature';
  }
}
