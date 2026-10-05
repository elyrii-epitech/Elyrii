import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/config/mascot_animations.dart';
import '../../../../core/config/mascot_themes.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/mascot_accessory.dart';
import '../../data/models/mascot_appearance.dart';
import '../../data/models/mascot_model.dart';

/// Provider gérant l'état et l'interaction avec la mascotte 3D.
///
/// Permet de contrôler le modèle 3D globalement, gérer les thèmes visuels
/// (palettes des matériaux), les pièces 3D de sa garde-robe et les
/// animations.
class MascotProvider extends ChangeNotifier {
  static const String _storageBase = 'elyrii_mascot_customization';
  static const String _themeBase = 'elyrii_mascot_theme';
  static const String _appearanceBase = 'elyrii_mascot_appearance';
  static const String _pendingSyncBase = 'elyrii_mascot_pending_sync';
  static const String _schemaBase = 'elyrii_mascot_schema_version';
  String? _userId;
  bool _isDemo;
  bool _sessionBound;
  int _sessionRevision = 0;
  Future<void>? _loadFuture;

  String get storageScope => _isDemo ? 'demo' : _userId ?? 'guest';
  int get sessionRevision => _sessionRevision;
  bool get _needsSync => _userId != null && !_isDemo;
  bool get _canSync => _client != null && _needsSync;
  String _key(String base, [String? scope]) =>
      '${base}_${scope ?? storageScope}';

  final ApiClient? _client;
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

  MascotProvider({ApiClient? client, String? userId, bool isDemo = false})
    : _client = client,
      _userId = userId,
      _isDemo = isDemo,
      _sessionBound = userId != null || isDemo {
    unawaited(_loadSavedMascot(_sessionRevision));
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
        () async {
          if (migrateLegacy && userId != null && !isDemo) {
            await _migrateLegacy(session);
          }
          if (session == _sessionRevision) await _loadMascot(session);
        }().whenComplete(() {
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
    _syncTail = Future<void>.value();
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

  Future<void> _migrateLegacy(int session) async {
    final scope = storageScope;
    final prefs = await SharedPreferences.getInstance();
    if (session != _sessionRevision) return;
    final owner = prefs.getString('elyrii_mascot_legacy_owner');
    if (owner != null && owner != scope) return;
    final cosmetics = prefs.getStringList(_storageBase);
    final theme = prefs.getString(_themeBase);
    final appearance = prefs.getString(_appearanceBase);
    if (cosmetics == null && theme == null && appearance == null) return;
    // Claim legacy preferences even when this account already has a scoped
    // cache, so another account cannot inherit them on a later launch.
    await prefs.setString('elyrii_mascot_legacy_owner', scope);
    if (prefs.containsKey(_key(_storageBase, scope)) ||
        prefs.containsKey(_key(_themeBase, scope)) ||
        prefs.containsKey(_key(_appearanceBase, scope))) {
      return;
    }
    if (cosmetics != null) {
      await prefs.setStringList(_key(_storageBase, scope), cosmetics);
    }
    if (theme != null) await prefs.setString(_key(_themeBase, scope), theme);
    if (appearance != null) {
      await prefs.setString(_key(_appearanceBase, scope), appearance);
    }
    await prefs.setBool(
      _key(_pendingSyncBase, scope),
      prefs.getBool(_pendingSyncBase) ?? false,
    );
    final seen = prefs.getStringList('elyrii_seen_cosmetic_unlocks');
    if (seen != null) {
      await prefs.setStringList('elyrii_seen_cosmetic_unlocks_$scope', seen);
    }
  }

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
    future = _loadMascot(_sessionRevision).whenComplete(() {
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
    if (session != _sessionRevision) return;

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
      final response =
          await _client!.get(ApiConfig.userMascotUrl) as Map<String, dynamic>;
      if (session != _sessionRevision ||
          _pendingSync ||
          localRevision != _syncRevision) {
        return;
      }
      _mascot = _mascotFromBackend(response);
      await _saveMascot();
    } catch (e) {
      if (session == _sessionRevision) {
        _error =
            'Ton look local reste disponible. La synchronisation sera réessayée.';
      }
    } finally {
      if (session == _sessionRevision) {
        _isLoading = false;
        _notify();
      }
    }
  }

  Future<void> _loadSavedMascot(int session) async {
    final scope = storageScope;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (session != _sessionRevision) return;
      _pendingSync = prefs.getBool(_key(_pendingSyncBase, scope)) ?? false;
      final hasScopedCache = [
        _storageBase,
        _themeBase,
        _appearanceBase,
      ].any((base) => prefs.containsKey(_key(base, scope)));
      final needsUpgrade =
          hasScopedCache && prefs.getInt(_key(_schemaBase, scope)) != 2;
      final legacyGuest =
          scope == 'guest' &&
          prefs.getString('elyrii_mascot_legacy_owner') == null;

      // Unscoped preferences are read only by the guest preview. A restored
      // authenticated account may explicitly claim its legacy cache once.
      final savedTheme =
          prefs.getString(_key(_themeBase, scope)) ??
          (legacyGuest ? prefs.getString(_themeBase) : null);
      if (savedTheme != null) {
        _mascot = _mascot.copyWith(themeId: _validThemeId(savedTheme));
      }

      final savedAppearance =
          prefs.getString(_key(_appearanceBase, scope)) ??
          (legacyGuest ? prefs.getString(_appearanceBase) : null);
      if (savedAppearance != null) {
        _mascot = _mascot.copyWith(
          appearance: MascotAppearance.fromJson(
            jsonDecode(savedAppearance) as Map<String, dynamic>,
          ),
        );
      }

      final rawCosmetics =
          prefs.getStringList(_key(_storageBase, scope)) ??
          (legacyGuest ? prefs.getStringList(_storageBase) : null);
      if (rawCosmetics != null) {
        final cosmetics = MascotAccessories.sanitizeSelection(rawCosmetics);
        _mascot = _mascot.copyWith(equippedCosmetics: cosmetics);
        if (!listEquals(rawCosmetics, cosmetics) &&
            prefs.containsKey(_key(_storageBase, scope))) {
          await prefs.setStringList(_key(_storageBase, scope), cosmetics);
        }
      }

      // Lucas's original studio saved only locally. Upload that cache once
      // before accepting a default server look during the first upgrade.
      if (session != _sessionRevision) return;
      if (needsUpgrade) {
        if (_needsSync) {
          _pendingSync = true;
          await prefs.setBool(_key(_pendingSyncBase, scope), true);
        }
        await prefs.setInt(_key(_schemaBase, scope), 2);
      }

      if (session == _sessionRevision) _notify();
    } catch (e) {
      if (session == _sessionRevision) {
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
        final prefs = await SharedPreferences.getInstance();
        if (pending) {
          await prefs.setBool(_key(_pendingSyncBase, scope), true);
        }
        final saved = await Future.wait([
          prefs.setStringList(
            _key(_storageBase, scope),
            snapshot.equippedCosmetics,
          ),
          prefs.setString(_key(_themeBase, scope), snapshot.themeId),
          prefs.setString(
            _key(_appearanceBase, scope),
            jsonEncode(snapshot.appearance.toJson()),
          ),
          prefs.setInt(_key(_schemaBase, scope), 2),
        ]);
        if (saved.any((success) => !success)) {
          throw StateError('Écriture refusée');
        }
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
        await _client!.put(
          ApiConfig.userMascotUrl,
          body: {
            'appearance': snapshot.themeId,
            'themeId': snapshot.themeId,
            'equippedCosmetics': snapshot.equippedCosmetics,
            'personality': {
              'equippedCosmetics': snapshot.equippedCosmetics,
              'customization': snapshot.appearance.toJson(),
            },
          },
        );
        if (session == _sessionRevision && revision == _syncRevision) {
          _pendingSync = false;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_key(_pendingSyncBase, scope), false);
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

  MascotModel _mascotFromBackend(Map<String, dynamic> json) {
    final personality = Map<String, dynamic>.from(
      json['personality'] as Map? ?? const <String, dynamic>{},
    );
    final rawTheme =
        json['appearance'] as String? ??
        personality['themeId'] as String? ??
        'nature';
    final themeId = _validThemeId(rawTheme == 'default' ? 'nature' : rawTheme);
    final cosmetics =
        (json['equippedCosmetics'] as List<dynamic>?) ??
        (personality['equippedCosmetics'] as List<dynamic>?) ??
        const <dynamic>[];

    return _mascot.copyWith(
      themeId: themeId,
      equippedCosmetics: MascotAccessories.sanitizeSelection(
        cosmetics.whereType<String>(),
      ),
      appearance: personality['customization'] is Map
          ? MascotAppearance.fromJson(
              Map<String, dynamic>.from(personality['customization'] as Map),
            )
          : _mascot.appearance,
    );
  }

  String _validThemeId(String themeId) {
    final exists = MascotThemes.all.any((theme) => theme.id == themeId);
    return exists ? themeId : 'nature';
  }
}
