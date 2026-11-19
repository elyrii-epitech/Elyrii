import 'package:flutter/material.dart';

/// Visual palette for the 3D mascot. [MascotThemes.colorsFor] supplies scene
/// material colors.
@immutable
class MascotTheme {
  /// Unique ID stored in SharedPreferences.
  final String id;

  /// Name displayed in the UI.
  final String name;

  /// Short description displayed below the name.
  final String description;

  /// Material icon representing the theme.
  final IconData icon;

  /// UI accent color for halos, selection, and related effects.
  final Color accentColor;

  /// Authored fur, ear/blush and eye colors, adapted from Lucas Debize's Esprits.
  final List<Color> paletteColors;

  /// Emoji used as a quick UI preview.
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

/// Available Elyrii mascot themes. The "nature" theme preserves original
/// textures; other palettes recolor the same model's materials without
/// replacing the scene.
class MascotThemes {
  MascotThemes._();

  /// Original peach-cream palette with pink ears.
  static const MascotTheme nature = MascotTheme(
    id: 'nature',
    name: 'Elyrii Originel',
    description: 'Crème pêche et regard myrtille, sa présence chaleureuse.',
    icon: Icons.spa_rounded,
    accentColor: Color(0xFF7E6AD8),
    paletteColors: [Color(0xFFEBCFAE), Color(0xFFFE9186), Color(0xFF543349)],
    emoji: '🌿',
  );

  /// Copper palette, retaining the legacy Halloween ID.
  static const MascotTheme halloween = MascotTheme(
    id: 'halloween',
    name: 'Automne Cuivré',
    description: 'La chaleur cuivrée des feuilles d’érable.',
    icon: Icons.pets_rounded,
    accentColor: Color(0xFFE67E22),
    paletteColors: [Color(0xFFE67E22), Color(0xFFC48668), Color(0xFF23150E)],
    emoji: '🎃',
  );

  /// Panda theme: desaturated black and white, with a soft, contrasting
  /// appearance.
  static const MascotTheme panda = MascotTheme(
    id: 'panda',
    name: 'Panda Mystique',
    description: 'Noir et blanc, doux et contrasté',
    icon: Icons.icecream_rounded,
    accentColor: Color(0xFF555555),
    paletteColors: [Color(0xFFF5F5F7), Color(0xFF263238), Color(0xFF121212)],
    emoji: '🐼',
  );

  /// Christmas theme: warm, festive red and green.
  static const MascotTheme noel = MascotTheme(
    id: 'noel',
    name: 'Noël',
    description: 'Rouge sapin et vert houx',
    icon: Icons.park_rounded,
    accentColor: Color(0xFFC0392B),
    paletteColors: [Color(0xFFC87982), Color(0xFFFE9186), Color(0xFF352B3B)],
    emoji: '🎄',
  );

  /// Lucas's Astral palette, retaining the legacy Cosmic ID.
  static const MascotTheme cosmic = MascotTheme(
    id: 'cosmic',
    name: 'Astral',
    description: 'Bleu nuit velouté et touches de champagne.',
    icon: Icons.auto_awesome_rounded,
    accentColor: Color(0xFF5B8DEE),
    paletteColors: [Color(0xFF2D3561), Color(0xFFF2CE94), Color(0xFF151833)],
    emoji: '🌌',
  );

  /// Ocean theme: fresh, soothing cyan and turquoise.
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

  /// Lucas's Spirits and the studio's legacy palettes.
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

  /// Finds a theme by ID.
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

  /// Finds a theme by ID, defaulting to [nature] when it does not exist.
  static MascotTheme getById(String? id) {
    if (id == null) return nature;
    return all.firstWhere((t) => t.id == id, orElse: () => nature);
  }
}
