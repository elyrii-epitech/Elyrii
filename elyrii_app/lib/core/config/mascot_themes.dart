import 'package:flutter/material.dart';

/// Représente un thème visuel appliqué à la mascotte 3D via une ColorMatrix.
///
/// Chaque thème défini une [ColorFilterMatrix] qui recolore le rendu 3D
/// à la volée (aucun nouveau GLB requis). Les thèmes saisonniers
/// permettent de donner du caractère à Elyrii selon les moments de l'année.
@immutable
class MascotTheme {
  /// Identifiant unique stocké en SharedPreferences.
  final String id;

  /// Nom affiché dans l'UI.
  final String name;

  /// Courte description affichée sous le nom.
  final String description;

  /// Icône Material représentative du thème.
  final IconData icon;

  /// Couleur d'accent utilisée dans l'UI (halo, sélection, etc.).
  final Color accentColor;

  /// Matrice 5x4 (List de 20 doubles) appliquée via [ColorFilter.matrix].
  /// Voir : https://developer.mozilla.org/en-US/docs/Web/CSS/filter-function/hue-rotate
  final List<double> colorMatrix;

  /// Emoji utilisé comme aperçu rapide dans l'UI.
  final String emoji;

  const MascotTheme({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.colorMatrix,
    required this.emoji,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MascotTheme &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Catalogue des thèmes disponibles pour la mascotte Elyrii.
///
/// Le thème "nature" correspond au rendu par défaut (pas de filtre).
/// Les autres thèmes appliquent une transformation colorimétrique
/// au modèle 3D existant, sans nécessiter de nouveaux assets.
class MascotThemes {
  MascotThemes._();

  /// Thème par défaut : lavande / menthe, rendu naturel.
  static const MascotTheme nature = MascotTheme(
    id: 'nature',
    name: 'Nature',
    description: 'Lavande et menthe, la présence douce d\'Elyrii',
    icon: Icons.spa_rounded,
    accentColor: Color(0xFF7E6AD8),
    colorMatrix: _identity,
    emoji: '🌿',
  );

  /// Thème Halloween : tons orange / violet, ambiance sorcière.
  static const MascotTheme halloween = MascotTheme(
    id: 'halloween',
    name: 'Halloween',
    description: 'Orange citrouille et violet nuit',
    icon: Icons.pets_rounded,
    accentColor: Color(0xFFE67E22),
    // Décalage de teinte vers l'orange (~-30°) + saturation accrue
    colorMatrix: [
      1.25, -0.15, 0.05, 0.0, -0.05, //
      -0.10, 0.85, 0.0, 0.0, -0.05, //
      -0.20, -0.10, 0.70, 0.0, 0.0, //
      0.0, 0.0, 0.0, 1.0, 0.0, //
    ],
    emoji: '🎃',
  );

  /// Thème Panda : noir et blanc désaturé, mignon et contrasté.
  static const MascotTheme panda = MascotTheme(
    id: 'panda',
    name: 'Panda',
    description: 'Noir et blanc, doux et contrasté',
    icon: Icons.icecream_rounded,
    accentColor: Color(0xFF555555),
    // Désaturation presque totale + léger contraste
    colorMatrix: [
      0.30, 0.60, 0.10, 0.0, 0.0, //
      0.30, 0.60, 0.10, 0.0, 0.0, //
      0.30, 0.60, 0.10, 0.0, 0.0, //
      0.0, 0.0, 0.0, 1.0, 0.0, //
    ],
    emoji: '🐼',
  );

  /// Thème Noël : rouge et vert, chaleureux et festif.
  static const MascotTheme noel = MascotTheme(
    id: 'noel',
    name: 'Noël',
    description: 'Rouge sapin et vert houx',
    icon: Icons.park_rounded,
    accentColor: Color(0xFFC0392B),
    // Décalage vers le rouge/vert saturé
    colorMatrix: [
      1.10, 0.05, -0.15, 0.0, -0.05, //
      -0.20, 1.00, 0.10, 0.0, 0.0, //
      -0.10, 0.10, 0.85, 0.0, 0.0, //
      0.0, 0.0, 0.0, 1.0, 0.0, //
    ],
    emoji: '🎄',
  );

  /// Thème Cosmic : bleu et violet néon, galactique.
  static const MascotTheme cosmic = MascotTheme(
    id: 'cosmic',
    name: 'Cosmic',
    description: 'Bleu néon et violet galactique',
    icon: Icons.auto_awesome_rounded,
    accentColor: Color(0xFF5B8DEE),
    // Décalage de teinte vers le bleu/violet + saturation
    colorMatrix: [
      0.50, 0.20, 0.40, 0.0, 0.0, //
      0.10, 0.60, 0.30, 0.0, 0.0, //
      0.30, 0.10, 1.10, 0.0, 0.0, //
      0.0, 0.0, 0.0, 1.0, 0.0, //
    ],
    emoji: '🌌',
  );

  /// Thème Ocean : cyan et turquoise, frais et apaisant.
  static const MascotTheme ocean = MascotTheme(
    id: 'ocean',
    name: 'Océan',
    description: 'Cyan turquoise et corail',
    icon: Icons.water_drop_rounded,
    accentColor: Color(0xFF26C6DA),
    // Décalage vers le cyan
    colorMatrix: [
      0.55, 0.25, 0.30, 0.0, 0.0, //
      0.15, 0.85, 0.20, 0.0, 0.0, //
      0.20, 0.25, 0.90, 0.0, 0.0, //
      0.0, 0.0, 0.0, 1.0, 0.0, //
    ],
    emoji: '🌊',
  );

  /// Tous les thèmes disponibles, dans l'ordre d'affichage.
  static const List<MascotTheme> all = [
    nature,
    halloween,
    panda,
    noel,
    cosmic,
    ocean,
  ];

  /// Récupère un thème par son identifiant.
  /// Retourne [nature] par défaut si l'id n'existe pas.
  static MascotTheme getById(String? id) {
    if (id == null) return nature;
    return all.firstWhere((t) => t.id == id, orElse: () => nature);
  }

  /// Matrice identité (pas de transformation).
  static const List<double> _identity = [
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}
