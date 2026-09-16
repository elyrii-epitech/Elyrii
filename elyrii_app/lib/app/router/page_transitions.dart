import 'package:flutter/cupertino.dart';

/// Transitions de page signature d'Elyrii.
///
/// Les pages poussées hors shell utilisent la transition Cupertino native
/// (glissement latéral depuis la droite) avec son geste de retour glissé
/// interactif — le swipe-back iOS — rétabli sur toutes les pages secondaires.
abstract final class ElyriiPageTransitions {
  /// Page plein écran entrant depuis la droite, retournable au glissé
  /// depuis le bord gauche (geste iOS natif).
  static Page<T> slideFromRight<T>({
    required Widget child,
    required LocalKey key,
    String? name,
  }) {
    return CupertinoPage<T>(key: key, name: name, child: child);
  }
}
