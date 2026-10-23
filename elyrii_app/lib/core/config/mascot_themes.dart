import 'package:flutter/material.dart';

/// Représente une palette visuelle de la mascotte 3D.
///
/// [MascotThemes.colorsFor] fournit les couleurs des matériaux de la scène.
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

  /// Authored fur, ear/blush and eye colors, adapted from Lucas Debize's Esprits.
  final List<Color> paletteColors;

  /// Emoji utilisé comme aperçu rapide dans l'UI.
  final String emoji;

  const MascotTheme({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.paletteColors,
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
/// Le thème "nature" conserve les textures d'origine. Les autres palettes
/// recolorent les matériaux du même modèle, sans remplacer la scène.
class MascotThemes {
  MascotThemes._();

  /// Palette crème pêche d’origine, avec ses oreilles roses.
  static const MascotTheme nature = MascotTheme(
    id: 'nature',
    name: 'Elyrii Originel',
    description: 'Crème pêche et regard myrtille, sa présence chaleureuse.',
    icon: Icons.spa_rounded,
    accentColor: Color(0xFF7E6AD8),
    paletteColors: [Color(0xFFEBCFAE), Color(0xFFFE9186), Color(0xFF543349)],
    emoji: '🌿',
  );

  /// Palette cuivrée ; l’identifiant historique Halloween est conservé.
  static const MascotTheme halloween = MascotTheme(
    id: 'halloween',
    name: 'Automne Cuivré',
    description: 'La chaleur cuivrée des feuilles d’érable.',
    icon: Icons.pets_rounded,
    accentColor: Color(0xFFE67E22),
    paletteColors: [Color(0xFFE67E22), Color(0xFFC48668), Color(0xFF23150E)],
    emoji: '🎃',
  );

  /// Thème Panda : noir et blanc désaturé, mignon et contrasté.
  static const MascotTheme panda = MascotTheme(
    id: 'panda',
    name: 'Panda Mystique',
    description: 'Noir et blanc, doux et contrasté',
    icon: Icons.icecream_rounded,
    accentColor: Color(0xFF555555),
    paletteColors: [Color(0xFFF5F5F7), Color(0xFF263238), Color(0xFF121212)],
    emoji: '🐼',
  );

  /// Thème Noël : rouge et vert, chaleureux et festif.
  static const MascotTheme noel = MascotTheme(
    id: 'noel',
    name: 'Noël',
    description: 'Rouge sapin et vert houx',
    icon: Icons.park_rounded,
    accentColor: Color(0xFFC0392B),
    paletteColors: [Color(0xFFC87982), Color(0xFFFE9186), Color(0xFF352B3B)],
    emoji: '🎄',
  );

  /// Palette Astral de Lucas ; l’identifiant historique Cosmic est conservé.
  static const MascotTheme cosmic = MascotTheme(
    id: 'cosmic',
    name: 'Astral',
    description: 'Bleu nuit velouté et touches de champagne.',
    icon: Icons.auto_awesome_rounded,
    accentColor: Color(0xFF5B8DEE),
    paletteColors: [Color(0xFF2D3561), Color(0xFFF2CE94), Color(0xFF151833)],
    emoji: '🌌',
  );

  /// Thème Ocean : cyan et turquoise, frais et apaisant.
  static const MascotTheme ocean = MascotTheme(
    id: 'ocean',
    name: 'Océan',
    description: 'Cyan turquoise et corail',
    icon: Icons.water_drop_rounded,
    accentColor: Color(0xFF26C6DA),
    paletteColors: [Color(0xFF78BEBB), Color(0xFFFE9186), Color(0xFF243C43)],
    emoji: '🌊',
  );

  static const MascotTheme zen = MascotTheme(
    id: 'zen',
    name: 'Esprit Zen',
    description: 'Sauge douce et calme intérieur des jardins de thé.',
    icon: Icons.self_improvement_rounded,
    accentColor: Color(0xFF5D9B6E),
    paletteColors: [Color(0xFF8AA882), Color(0xFFC8E6C9), Color(0xFF152418)],
    emoji: '🍵',
  );

  static const MascotTheme sakura = MascotTheme(
    id: 'sakura',
    name: 'Sakura Céleste',
    description: 'Rose poudré et douceur des cerisiers en fleurs.',
    icon: Icons.filter_vintage_rounded,
    accentColor: Color(0xFFEC407A),
    paletteColors: [Color(0xFFF48FB1), Color(0xFFF8BBD0), Color(0xFF2E1042)],
    emoji: '🌸',
  );

  /// Les Esprits de Lucas et les palettes historiques du studio.
  static const List<MascotTheme> all = [
    nature,
    cosmic,
    zen,
    sakura,
    halloween,
    panda,
    noel,
    ocean,
  ];

  /// Récupère un thème par son identifiant.
  static Map<String, String> colorsFor(String id) => switch (id) {
    'halloween' => {
      'body': '#E67E22',
      'details': '#FFF8E1',
      'ears': '#C48668',
      'eyes': '#23150E',
    },
    'panda' => {
      'body': '#F5F5F7',
      'details': '#FFFFFF',
      'ears': '#263238',
      'eyes': '#121212',
    },
    'noel' => {'body': '#C87982', 'details': '#EFE9DC', 'eyes': '#352B3B'},
    'cosmic' => {
      'body': '#2D3561',
      'details': '#C5CAE9',
      'ears': '#F2CE94',
      'eyes': '#151833',
    },
    'zen' => {
      'body': '#8AA882',
      'details': '#F1F8E9',
      'ears': '#C8E6C9',
      'eyes': '#152418',
    },
    'sakura' => {
      'body': '#F48FB1',
      'details': '#FFF5F8',
      'ears': '#F8BBD0',
      'eyes': '#2E1042',
    },
    'ocean' => {'body': '#78BEBB', 'details': '#E2F2EE', 'eyes': '#243C43'},
    _ => const {},
  };

  /// Récupère un thème par son identifiant.
  /// Retourne [nature] par défaut si l'id n'existe pas.
  static MascotTheme getById(String? id) {
    if (id == null) return nature;
    return all.firstWhere((t) => t.id == id, orElse: () => nature);
  }
}
