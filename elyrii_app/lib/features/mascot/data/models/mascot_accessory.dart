import 'package:flutter/foundation.dart';

/// Une pièce 3D de la garde-robe d'Elyrii, débloquée par les défis terminés.
/// Son identifiant correspond à la variante du modèle de la mascotte.
@immutable
class MascotAccessory {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final String category;
  final int requiredChallenges;

  const MascotAccessory({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.category,
    required this.requiredChallenges,
  });

  bool isUnlocked(int completedChallenges) =>
      completedChallenges >= requiredChallenges;

  int remainingChallenges(int completedChallenges) =>
      (requiredChallenges - completedChallenges).clamp(0, requiredChallenges);

  String get unlockLabel =>
      '$requiredChallenges ${requiredChallenges == 1 ? 'défi terminé' : 'défis terminés'}';
}

/// Catalogue commun au rendu, à la personnalisation et à la sauvegarde.
abstract final class MascotAccessories {
  /// Preserve saved looks from Lucas's earlier wardrobe identifiers.
  static const legacyIds = {
    'custom1': 'graduate_cap',
    'crown_laurel': 'laurel_crown',
    'flower_mouth': 'cheek_sparkle',
    'scarf_cozy': 'cozy_scarf',
    'bowtie_chic': 'bow_tie',
    'zen_necklace': 'leaf_pendant',
    'glasses_round': 'round_glasses',
    'headphones_zen': 'headphones',
  };

  static const all = <MascotAccessory>[
    MascotAccessory(
      id: 'beret',
      name: 'Béret sauge',
      description: 'Une forme souple et arrondie pour un esprit créatif.',
      emoji: '🎨',
      category: 'Tête',
      requiredChallenges: 2,
    ),
    MascotAccessory(
      id: 'beanie',
      name: 'Bonnet douillet',
      description: 'Un bonnet à pompon pour les moments de douceur.',
      emoji: '🧶',
      category: 'Tête',
      requiredChallenges: 3,
    ),
    MascotAccessory(
      id: 'flower_crown',
      name: 'Couronne de fleurs',
      description:
          'De petites fleurs pour une touche printanière tout en douceur.',
      emoji: '🌸',
      category: 'Tête',
      requiredChallenges: 5,
    ),
    MascotAccessory(
      id: 'star_crown',
      name: 'Couronne d’étoiles',
      description: 'De fines étoiles dorées pour faire briller tes progrès.',
      emoji: '⭐',
      category: 'Tête',
      requiredChallenges: 7,
    ),
    MascotAccessory(
      id: 'moon_pin',
      name: 'Broche lunaire',
      description: 'Un croissant de lune discret, posé près de son oreille.',
      emoji: '🌙',
      category: 'Tête',
      requiredChallenges: 9,
    ),
    MascotAccessory(
      id: 'graduate_cap',
      name: 'Chapeau de diplômé',
      description:
          'Une coiffe bleu nuit et son pompon doré pour célébrer tes premiers pas.',
      emoji: '🎓',
      category: 'Tête',
      requiredChallenges: 1,
    ),
    MascotAccessory(
      id: 'laurel_crown',
      name: 'Couronne de laurier',
      description:
          'Des feuilles sculptées et de petites touches dorées pour marquer tes progrès.',
      emoji: '🌿',
      category: 'Tête',
      requiredChallenges: 3,
    ),
    MascotAccessory(
      id: 'round_glasses',
      name: 'Lunettes rondes',
      description:
          'Une monture légère qui laisse voir son regard bienveillant.',
      emoji: '👓',
      category: 'Visage',
      requiredChallenges: 12,
    ),
    MascotAccessory(
      id: 'headphones',
      name: 'Casque pastel',
      description: 'Deux coussinets moelleux pour une parenthèse musicale.',
      emoji: '🎧',
      category: 'Visage',
      requiredChallenges: 15,
    ),
    MascotAccessory(
      id: 'sleep_mask',
      name: 'Masque de repos',
      description:
          'Un masque tout doux pour rappeler que le repos compte aussi.',
      emoji: '💤',
      category: 'Visage',
      requiredChallenges: 18,
    ),
    MascotAccessory(
      id: 'cheek_sparkle',
      name: 'Éclat céleste',
      description:
          'Un petit éclat lumineux posé sur la joue, comme une étoile personnelle.',
      emoji: '✨',
      category: 'Visage',
      requiredChallenges: 4,
    ),
    MascotAccessory(
      id: 'cozy_scarf',
      name: 'Écharpe cocon',
      description:
          'Une écharpe courte aux bords arrondis, comme un petit câlin.',
      emoji: '🧣',
      category: 'Cou',
      requiredChallenges: 22,
    ),
    MascotAccessory(
      id: 'bow_tie',
      name: 'Nœud papillon',
      description: 'Un petit nœud festif, à la mesure de sa silhouette ronde.',
      emoji: '🎀',
      category: 'Cou',
      requiredChallenges: 26,
    ),
    MascotAccessory(
      id: 'leaf_pendant',
      name: 'Pendentif feuille',
      description: 'Une feuille portée près du cœur, en écho à la nature.',
      emoji: '🍃',
      category: 'Cou',
      requiredChallenges: 30,
    ),
    MascotAccessory(
      id: 'mini_backpack',
      name: 'Petit sac à dos',
      description: 'Un sac miniature pour accompagner le chemin parcouru.',
      emoji: '🎒',
      category: 'Dos',
      requiredChallenges: 36,
    ),
  ];

  static MascotAccessory? byId(String id) {
    id = legacyIds[id] ?? id;
    for (final accessory in all) {
      if (accessory.id == id) return accessory;
    }
    return null;
  }

  /// One accessory per attachment category; keep the last selection in a slot.
  /// Canonical catalogue order also identifies the corresponding GLB variant.
  static List<String> sanitizeSelection(Iterable<String> ids) {
    final slots = <String, String>{};
    for (final id in ids) {
      final accessory = byId(id);
      if (accessory != null) slots[accessory.category] = accessory.id;
    }
    return List<String>.unmodifiable(
      all
          .where((accessory) => slots[accessory.category] == accessory.id)
          .map((accessory) => accessory.id),
    );
  }

  static List<MascotAccessory> get progression {
    final pieces = List<MascotAccessory>.from(all);
    pieces.sort((a, b) {
      final threshold = a.requiredChallenges.compareTo(b.requiredChallenges);
      return threshold == 0
          ? all.indexOf(a).compareTo(all.indexOf(b))
          : threshold;
    });
    return List.unmodifiable(pieces);
  }

  static int get maxRequiredChallenges => progression.last.requiredChallenges;

  static String? variantFor(Iterable<String> ids) {
    final selection = sanitizeSelection(ids);
    return selection.isEmpty ? null : selection.join('+');
  }
}
