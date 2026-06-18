import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/mascot_themes.dart';
import '../../data/models/mascot_model.dart';

/// Provider gérant l'état et l'interaction avec la mascotte 3D.
///
/// Permet de contrôler le modèle 3D globalement, gérer les thèmes visuels
/// (recoloration via ColorFilter) et préparer le terrain pour les
/// accessoires futurs et le contrôle des animations.
class MascotProvider extends ChangeNotifier {
  static const String _storageKey = 'elyrii_mascot_customization';
  static const String _themeKey = 'elyrii_mascot_theme';

  MascotModel _mascot = MascotModel.defaultMascot();

  String? _error;

  MascotProvider() {
    _loadSavedMascot();
  }

  MascotModel get mascot => _mascot;

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
  }

  /// Réinitialise l'état de la mascotte par défaut
  void resetToDefault() {
    _mascot = MascotModel.defaultMascot();
    _error = null;
    notifyListeners();
    _saveMascot();
    _saveTheme('nature');
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
}
