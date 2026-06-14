import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/mascot_model.dart';

/// Provider gérant l'état et l'interaction avec la mascotte 3D.
///
/// Permet de contrôler le modèle 3D globalement et prépare le terrain
/// pour la personnalisation (cosmétiques, accessoires) et le contrôle
/// des animations futures.
class MascotProvider extends ChangeNotifier {
  static const String _storageKey = 'elyrii_mascot_customization';

  /// L'état de la mascotte (modèle de données)
  MascotModel _mascot = MascotModel.defaultMascot();

  /// Contrôleur de l'affichage 3D de la mascotte
  final Flutter3DController _controller = Flutter3DController();

  /// Indique si le modèle 3D est en cours de chargement
  bool _isLoading = false;

  /// Message d'erreur éventuel en cas d'échec de chargement
  String? _error;

  MascotProvider() {
    _loadSavedMascot();
  }

  // ==================== GETTERS ====================

  /// L'état courant de la mascotte
  MascotModel get mascot => _mascot;

  /// Le contrôleur 3D exposé pour piloter le modèle
  Flutter3DController get controller => _controller;

  /// Si le chargement est en cours
  bool get isLoading => _isLoading;

  /// Message d'erreur s'il y en a un
  String? get error => _error;

  /// Si la mascotte a une erreur
  bool get hasError => _error != null;

  // ==================== ACTIONS ====================

  /// Définit si le modèle est en cours de chargement
  void setLoading(bool loading) {
    if (_isLoading == loading) return;
    _isLoading = loading;
    notifyListeners();
  }

  /// Définit une erreur de chargement
  void setError(String? errorMessage) {
    _error = errorMessage;
    notifyListeners();
  }

  /// Change l'animation de la mascotte si elle est disponible dans le .glb.
  Future<void> changeAnimation(String animationName) async {
    if (_mascot.animationState == animationName) return;

    try {
      _controller.playAnimation(animationName: animationName);
      _mascot = _mascot.copyWith(animationState: animationName);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = "Impossible de jouer l'animation $animationName: $e";
      notifyListeners();
    }
  }

  /// Sélectionne ou retire un détail visuel (aura, accessoire futur, ambiance).
  ///
  /// Prépare le terrain pour la customisation future de la mascotte.
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
    _isLoading = false;
    _error = null;
    notifyListeners();
    _saveMascot();
  }

  Future<void> _loadSavedMascot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawCosmetics = prefs.getStringList(_storageKey);
      if (rawCosmetics == null) return;

      _mascot = _mascot.copyWith(equippedCosmetics: rawCosmetics);
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
}
