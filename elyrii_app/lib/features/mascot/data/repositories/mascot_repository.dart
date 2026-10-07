import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/config/mascot_themes.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/json_response.dart';
import '../models/mascot_model.dart';
import '../models/mascot_appearance.dart';
import '../models/mascot_accessory.dart';

/// Account-scoped local schema/migration and remote DTO boundary for the studio.
class MascotRepository {
  MascotRepository({this._client});
  final ApiClient? _client;
  bool get canSync => _client != null;
  static const String _storageBase = 'elyrii_mascot_customization';
  static const String _themeBase = 'elyrii_mascot_theme';
  static const String _appearanceBase = 'elyrii_mascot_appearance';
  static const String _pendingSyncBase = 'elyrii_mascot_pending_sync';
  static const String _schemaBase = 'elyrii_mascot_schema_version';
  String _key(String base, String scope) => '${base}_$scope';
  Future<void> migrateLegacy(String scope, bool Function() isCurrent) async {
    final prefs = await SharedPreferences.getInstance();
    if (!isCurrent()) return;
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

  Future<({MascotModel? model, bool pending})> readLocal(
    String scope, {
    required bool needsSync,
    required bool Function() isCurrent,
  }) async {
    var model = MascotModel.defaultMascot();
    var pending = false;
    final prefs = await SharedPreferences.getInstance();
    if (!isCurrent()) return (model: null, pending: false);
    pending = prefs.getBool(_key(_pendingSyncBase, scope)) ?? false;
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
      model = model.copyWith(themeId: _validThemeId(savedTheme));
    }

    final savedAppearance =
        prefs.getString(_key(_appearanceBase, scope)) ??
        (legacyGuest ? prefs.getString(_appearanceBase) : null);
    if (savedAppearance != null) {
      model = model.copyWith(
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
      model = model.copyWith(equippedCosmetics: cosmetics);
      if (!listEquals(rawCosmetics, cosmetics) &&
          prefs.containsKey(_key(_storageBase, scope))) {
        await prefs.setStringList(_key(_storageBase, scope), cosmetics);
      }
    }

    // Lucas's original studio saved only locally. Upload that cache once
    // before accepting a default server look during the first upgrade.
    if (!isCurrent()) return (model: null, pending: false);
    if (needsUpgrade) {
      if (needsSync) {
        pending = true;
        await prefs.setBool(_key(_pendingSyncBase, scope), true);
      }
      await prefs.setInt(_key(_schemaBase, scope), 2);
    }

    return (model: model, pending: pending);
  }

  Future<void> writeLocal(
    String scope,
    MascotModel value, {
    required bool pending,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (pending) await prefs.setBool(_key(_pendingSyncBase, scope), true);
    final saved = await Future.wait([
      prefs.setStringList(_key(_storageBase, scope), value.equippedCosmetics),
      prefs.setString(_key(_themeBase, scope), value.themeId),
      prefs.setString(
        _key(_appearanceBase, scope),
        jsonEncode(value.appearance.toJson()),
      ),
      prefs.setInt(_key(_schemaBase, scope), 2),
    ]);
    if (saved.any((result) => !result)) throw StateError('Local write refused');
  }

  Future<void> markSynced(String scope) async {
    await (await SharedPreferences.getInstance()).setBool(
      _key(_pendingSyncBase, scope),
      false,
    );
  }

  Future<MascotModel> getRemote(MascotModel fallback) async => decodeResponse(
    await _client!.get(ApiConfig.userMascotUrl),
    (json) => _mascotFromBackend(json, fallback),
  );
  Future<void> saveRemote(MascotModel value) async {
    await _client!.put(
      ApiConfig.userMascotUrl,
      body: {
        'appearance': value.themeId,
        'themeId': value.themeId,
        'equippedCosmetics': value.equippedCosmetics,
        'personality': {
          'equippedCosmetics': value.equippedCosmetics,
          'customization': value.appearance.toJson(),
        },
      },
    );
  }

  MascotModel _mascotFromBackend(
    Map<String, dynamic> json,
    MascotModel fallback,
  ) {
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

    return fallback.copyWith(
      themeId: themeId,
      equippedCosmetics: MascotAccessories.sanitizeSelection(
        cosmetics.whereType<String>(),
      ),
      appearance: personality['customization'] is Map
          ? MascotAppearance.fromJson(
              Map<String, dynamic>.from(personality['customization'] as Map),
            )
          : fallback.appearance,
    );
  }

  String _validThemeId(String themeId) {
    final exists = MascotThemes.all.any((theme) => theme.id == themeId);
    return exists ? themeId : 'nature';
  }
}
