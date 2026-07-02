import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/config/mascot_themes.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/mascot_model.dart';

/// Provider gérant l'état et l'interaction avec la mascotte 3D.
///
/// Permet de contrôler le modèle 3D globalement, gérer les thèmes visuels
/// (recoloration via ColorFilter) et préparer le terrain pour les
/// accessoires futurs et le contrôle des animations.
class MascotProvider extends ChangeNotifier {
  static const String _storageKey = 'elyrii_mascot_customization';
  static const String _themeKey = 'elyrii_mascot_theme';

  final ApiClient? _client;
  MascotModel _mascot = MascotModel.defaultMascot();

  bool _isLoading = false;
  bool _isSyncing = false;
  String? _error;

  MascotProvider({ApiClient? client}) : _client = client {
    _loadSavedMascot();
  }

  MascotModel get mascot => _mascot;

  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get error => _error;

  MascotTheme get currentTheme => MascotThemes.getById(_mascot.themeId);

  /// Applique un thème visuel à la mascotte.
  ///
  /// Le thème recolore le modèle 3D à la volée via une ColorMatrix,
  /// sans nécessiter de nouveau fichier GLB.
  void setTheme(String themeId) {
    if (_mascot.themeId == themeId) return;

    _mascot = _mascot.copyWith(themeId: themeId);
    notifyListeners();
    _saveTheme(themeId);
    unawaited(_syncToBackend());
  }

  /// Sélectionne ou retire un détail visuel (accessoire futur).
  void equipCosmetic(String cosmeticId) {
    final List<String> updatedCosmetics = List.from(_mascot.equippedCosmetics);
    if (updatedCosmetics.contains(cosmeticId)) {
      updatedCosmetics.remove(cosmeticId);
    } else {
      updatedCosmetics.add(cosmeticId);
    }

    _mascot = _mascot.copyWith(equippedCosmetics: updatedCosmetics);
    notifyListeners();
    _saveMascot();
    unawaited(_syncToBackend());
  }

  /// Réinitialise l'état de la mascotte par défaut
  void resetToDefault() {
    _mascot = MascotModel.defaultMascot();
    _error = null;
    notifyListeners();
    _saveMascot();
    _saveTheme('nature');
    unawaited(_syncToBackend());
  }

  Future<void> loadMascot() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    await _loadSavedMascot();

    if (_client == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final response =
          await _client.get(ApiConfig.userMascotUrl) as Map<String, dynamic>;
      _mascot = _mascotFromBackend(response);
      await _saveMascot();
      await _saveTheme(_mascot.themeId);
    } catch (e) {
      _error = 'Impossible de charger la mascotte depuis le serveur: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadSavedMascot() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedTheme = prefs.getString(_themeKey);
      if (savedTheme != null && savedTheme != 'nature') {
        _mascot = _mascot.copyWith(themeId: savedTheme);
      }

      final rawCosmetics = prefs.getStringList(_storageKey);
      if (rawCosmetics != null) {
        _mascot = _mascot.copyWith(equippedCosmetics: rawCosmetics);
      }

      notifyListeners();
    } catch (e) {
      _error = 'Impossible de charger la personnalisation: $e';
      notifyListeners();
    }
  }

  Future<void> _saveMascot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_storageKey, _mascot.equippedCosmetics);
    } catch (e) {
      _error = 'Impossible de sauvegarder la personnalisation: $e';
      notifyListeners();
    }
  }

  Future<void> _saveTheme(String themeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, themeId);
    } catch (e) {
      _error = 'Impossible de sauvegarder le thème: $e';
      notifyListeners();
    }
  }

  Future<void> _syncToBackend() async {
    if (_client == null) return;

    _isSyncing = true;
    _error = null;
    notifyListeners();

    try {
      await _client.put(
        ApiConfig.userMascotUrl,
        body: {
          'appearance': _mascot.themeId,
          'themeId': _mascot.themeId,
          'equippedCosmetics': _mascot.equippedCosmetics,
          'personality': {'equippedCosmetics': _mascot.equippedCosmetics},
        },
      );
    } catch (e) {
      _error = 'Impossible de synchroniser la mascotte: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
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
      equippedCosmetics: cosmetics.map((item) => item.toString()).toList(),
    );
  }

  String _validThemeId(String themeId) {
    final exists = MascotThemes.all.any((theme) => theme.id == themeId);
    return exists ? themeId : 'nature';
  }
}
