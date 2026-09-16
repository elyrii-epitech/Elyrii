import 'package:flutter/services.dart';

/// Système haptique centralisé respectueux des préférences de l'utilisateur.
/// Tous les retours tactiles de l'application DOIVENT passer par cette API.
abstract final class ElyriiHaptics {
  static bool _enabled = true;

  /// Indique si les vibrations haptiques sont actuellement activées.
  static bool get isEnabled => _enabled;

  /// Configure l'activation globale du retour haptique (synchronisé avec les réglages).
  static void setEnabled(bool enabled) => _enabled = enabled;

  /// Clic léger de sélection (onglets, chips, toggles)
  static void selection() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
  }

  /// Impact subtil (bouton standard, ouverture de fiche)
  static void light() {
    if (!_enabled) return;
    HapticFeedback.lightImpact();
  }

  /// Impact moyen (action de validation, enregistrement humeur)
  static void medium() {
    if (!_enabled) return;
    HapticFeedback.mediumImpact();
  }

  /// Succès (fin de séance de respiration, défi validé)
  static void success() {
    if (!_enabled) return;
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_enabled) HapticFeedback.lightImpact();
    });
  }

  /// Avertissement ou sortie de session
  static void warning() {
    if (!_enabled) return;
    HapticFeedback.heavyImpact();
  }
}
