import 'package:flutter/material.dart';

/// Représente un Esprit visuel d'Elyrii avec son variant glTF 3D natif.
///
/// Chaque esprit correspond à une incarnation artistique complète de la mascotte
/// (pelage, oreilles, yeux, ventre et museau) avec sa propre palette haute
/// définition commutée nativement via l'extension glTF `KHR_materials_variants`.
@immutable
class MascotTheme {
  /// Identifiant unique stocké en SharedPreferences.
  final String id;

  /// Nom de la variante glTF KHR_materials_variants correspondante dans le modèle 3D.
  final String variantName;

  /// Nom poétique affiché dans l'UI.
  final String name;

  /// Courte description affichée sous le nom.
  final String description;

  /// Icône Material représentative de l'esprit.
  final IconData icon;

  /// Couleur d'accent utilisée dans l'UI (halo, sélection, etc.).
  final Color accentColor;

  /// Palette des 3 couleurs caractéristiques de l'esprit : [pelage, oreilles, regard].
  /// Utilisée pour afficher des swatches authentiques dans l'atelier de personnalisation.
  final List<Color> paletteColors;

  /// Matrice 5x4 optionnelle pour rétrocompatibilité 2D.
  final List<double> colorMatrix;

  /// Emoji utilisé comme aperçu rapide dans l'UI.
  final String emoji;

  const MascotTheme({
    required this.id,
    required this.variantName,
    required this.name,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.paletteColors,
    this.colorMatrix = _identity,
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

  /// Matrice identité standard (sans distorsion de teinte).
  static const List<double> _identity = [
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

/// Catalogue des 6 Esprits d'Elyrii disponibles dans le modèle 3D multi-variants.
class MascotThemes {
  MascotThemes._();

  /// Esprit 1 : Elyrii Originel — Crème pêche velouté, oreilles framboise douce, regard myrtille.
  static const MascotTheme nature = MascotTheme(
    id: 'nature',
    variantName: 'Elyrii',
    name: 'Elyrii Originel',
    description: 'La présence bienveillante et chaleureuse du compagnon originel.',
    icon: Icons.spa_rounded,
    accentColor: Color(0xFF7E6AD8),
    paletteColors: [
      Color(0xFFF2D0A8), // Crème pêche velouté
      Color(0xFFFE9186), // Oreilles framboise douce
      Color(0xFF420E30), // Regard myrtille
    ],
    emoji: '🌿',
  );

  /// Esprit 2 : Renard Astral — Pelage bleu nuit velours, oreilles or champagne doux, regard nuit étoilée.
  static const MascotTheme cosmic = MascotTheme(
    id: 'cosmic',
    variantName: 'Astral',
    name: 'Renard Astral',
    description: 'Une aura nocturne et mystique venue des confins des constellations.',
    icon: Icons.auto_awesome_rounded,
    accentColor: Color(0xFF5B8DEE),
    paletteColors: [
      Color(0xFF2D3561), // Bleu nuit indigo velours
      Color(0xFFF2CE94), // Or champagne doux
      Color(0xFF151833), // Regard nuit étoilée
    ],
    colorMatrix: [
      0.50, 0.20, 0.40, 0.0, 0.0, //
      0.10, 0.60, 0.30, 0.0, 0.0, //
      0.30, 0.10, 1.10, 0.0, 0.0, //
      0.0, 0.0, 0.0, 1.0, 0.0, //
    ],
    emoji: '🌌',
  );

  /// Esprit 3 : Esprit Zen — Pelage vert sauge doux, oreilles thé matcha, regard forêt profonde.
  static const MascotTheme zen = MascotTheme(
    id: 'zen',
    variantName: 'Zen',
    name: 'Esprit Zen',
    description: 'Sérénité végétale et calme intérieur inspirés des jardins de thé.',
    icon: Icons.self_improvement_rounded,
    accentColor: Color(0xFF5D9B6E),
    paletteColors: [
      Color(0xFF8AA882), // Vert sauge doux
      Color(0xFFC8E6C9), // Thé matcha tendre
      Color(0xFF1B3320), // Forêt profonde
    ],
    colorMatrix: [
      0.55, 0.25, 0.30, 0.0, 0.0, //
      0.15, 0.85, 0.20, 0.0, 0.0, //
      0.20, 0.25, 0.90, 0.0, 0.0, //
      0.0, 0.0, 0.0, 1.0, 0.0, //
    ],
    emoji: '🍵',
  );

  /// Esprit 4 : Automne Cuivré — Pelage roux flamboyant, oreilles chocolat noisette, regard espresso.
  static const MascotTheme halloween = MascotTheme(
    id: 'halloween',
    variantName: 'Automne',
    name: 'Automne Cuivré',
    description: 'Chaleur réconfortante des feuilles d’érable et des feux de cheminée.',
    icon: Icons.local_fire_department_rounded,
    accentColor: Color(0xFFE67E22),
    paletteColors: [
      Color(0xFFE67E22), // Roux flamboyant cuivré
      Color(0xFF5D4037), // Chocolat noisette
      Color(0xFF2E1C14), // Espresso profond
    ],
    colorMatrix: [
      1.25, -0.15, 0.05, 0.0, -0.05, //
      -0.10, 0.85, 0.0, 0.0, -0.05, //
      -0.20, -0.10, 0.70, 0.0, 0.0, //
      0.0, 0.0, 0.0, 1.0, 0.0, //
    ],
    emoji: '🍂',
  );

  /// Esprit 5 : Sakura Céleste — Pelage rose nuage poudré, oreilles pêche nacrée, regard baies pourpres.
  static const MascotTheme sakura = MascotTheme(
    id: 'sakura',
    variantName: 'Sakura',
    name: 'Sakura Céleste',
    description: 'Délicatesse printanière et poésie inspirée des cerisiers en fleurs.',
    icon: Icons.filter_vintage_rounded,
    accentColor: Color(0xFFEC407A),
    paletteColors: [
      Color(0xFFF48FB1), // Rose poudré nuage
      Color(0xFFFFE0B2), // Pêche nacrée
      Color(0xFF4A148C), // Baies pourpres
    ],
    colorMatrix: [
      1.20, 0.18, 0.22, 0.0, 0.04, //
      0.02, 0.72, 0.16, 0.0, 0.0, //
      0.12, 0.08, 0.92, 0.0, 0.04, //
      0.0, 0.0, 0.0, 1.0, 0.0, //
    ],
    emoji: '🌸',
  );

  /// Esprit 6 : Panda Mystique — Pelage blanc neige soyeux, oreilles encre de Chine, regard onyx profond.
  static const MascotTheme panda = MascotTheme(
    id: 'panda',
    variantName: 'Panda',
    name: 'Panda Mystique',
    description: 'Pureté minimaliste et contraste apaisant d’une silhouette zen.',
    icon: Icons.pets_rounded,
    accentColor: Color(0xFF424242),
    paletteColors: [
      Color(0xFFF5F5F7), // Blanc neige soyeux
      Color(0xFF263238), // Encre de Chine veloutée
      Color(0xFF121212), // Onyx profond
    ],
    colorMatrix: [
      0.30, 0.60, 0.10, 0.0, 0.0, //
      0.30, 0.60, 0.10, 0.0, 0.0, //
      0.30, 0.60, 0.10, 0.0, 0.0, //
      0.0, 0.0, 0.0, 1.0, 0.0, //
    ],
    emoji: '🐼',
  );

  /// Les 6 Esprits d'Elyrii disponibles dans l'atelier de personnalisation.
  static const List<MascotTheme> all = [
    nature,
    cosmic,
    zen,
    halloween,
    sakura,
    panda,
  ];

  /// Récupère un esprit par son identifiant avec rétrocompatibilité assurée.
  /// Si l'identifiant est inconnu ou ancien (ex: ocean, noel), bascule harmonieusement
  /// sur un esprit équivalent ou sur [nature].
  static MascotTheme getById(String? id) {
    if (id == null) return nature;
    switch (id) {
      case 'nature':
        return nature;
      case 'cosmic':
        return cosmic;
      case 'zen':
        return zen;
      case 'halloween':
        return halloween;
      case 'sakura':
        return sakura;
      case 'panda':
        return panda;
      case 'ocean':
        return zen;
      case 'noel':
        return halloween;
      default:
        return all.firstWhere((t) => t.id == id, orElse: () => nature);
    }
  }
}
