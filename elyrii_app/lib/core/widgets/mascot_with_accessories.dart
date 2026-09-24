import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/mascot_3d_config.dart';
import '../config/mascot_themes.dart';
import 'mascot_3d_viewer.dart';
import 'mascot_model_surface.dart';
import '../config/mascot_animations.dart';
import '../../features/mascot/presentation/providers/mascot_provider.dart';

/// Définition de rendu d'un accessoire superposé à la mascotte 3D.
///
/// Chaque accessoire est positionné par ratio par rapport à la taille de la
/// mascotte afin de rester parfaitement ajusté quelle que soit la dimension.
@immutable
class AccessoryRender {
  /// Identifiant correspondant à un cosmétique équipé ([MascotModel.equippedCosmetics]).
  final String id;

  /// Famille d'accessoire : 'Habillage', 'Tête', 'Visage'.
  final String category;

  /// Chemin vers le fichier .glb de l'accessoire.
  final String assetPath;

  /// Taille de l'accessoire en ratio de la largeur de la mascotte.
  final double sizeRatio;

  /// Position verticale (depuis le haut) en ratio de la hauteur de la mascotte.
  final double topRatio;

  /// Décalage horizontal en ratio de la largeur (0 = centré).
  final double horizontalOffsetRatio;

  const AccessoryRender({
    required this.id,
    required this.category,
    required this.assetPath,
    required this.sizeRatio,
    required this.topRatio,
    this.horizontalOffsetRatio = 0,
  });
}

/// Catalogue centralisé des 8 tenues et accessoires 3D de la mascotte Elyrii.
class MascotAccessoryCatalog {
  MascotAccessoryCatalog._();

  // --- Catégorie Habillage (Corps / Cou) ---

  /// Écharpe Moelleuse Cocon en laine terracotta chaude.
  static const AccessoryRender scarfCozy = AccessoryRender(
    id: 'scarf_cozy',
    category: 'Habillage',
    assetPath: 'assets/accessories/scarf_cozy.glb',
    sizeRatio: 0.48,
    topRatio: 0.48,
    horizontalOffsetRatio: 0,
  );

  /// Nœud Papillon Célébration en ruban pourpre avec anneau doré.
  static const AccessoryRender bowtieChic = AccessoryRender(
    id: 'bowtie_chic',
    category: 'Habillage',
    assetPath: 'assets/accessories/bowtie_chic.glb',
    sizeRatio: 0.30,
    topRatio: 0.50,
    horizontalOffsetRatio: 0,
  );

  /// Collier Lotus Zen en perles de bois et médaillon lotus doré.
  static const AccessoryRender zenNecklace = AccessoryRender(
    id: 'zen_necklace',
    category: 'Habillage',
    assetPath: 'assets/accessories/zen_necklace.glb',
    sizeRatio: 0.45,
    topRatio: 0.48,
    horizontalOffsetRatio: 0,
  );

  // --- Catégorie Tête (Sommet du crâne) ---

  /// Chapeau de diplômé d'honneur.
  static const AccessoryRender custom1 = AccessoryRender(
    id: 'custom1',
    category: 'Tête',
    assetPath: 'assets/custom1.glb',
    sizeRatio: 0.46,
    topRatio: 0.0,
    horizontalOffsetRatio: 0,
  );

  /// Couronne de Laurier Zen aux feuilles dorées.
  static const AccessoryRender crownLaurel = AccessoryRender(
    id: 'crown_laurel',
    category: 'Tête',
    assetPath: 'assets/accessories/crown_laurel.glb',
    sizeRatio: 0.46,
    topRatio: 0.05,
    horizontalOffsetRatio: 0,
  );

  /// Casque Audio Pleine Conscience arceau doux et coussinets menthe.
  static const AccessoryRender headphonesZen = AccessoryRender(
    id: 'headphones_zen',
    category: 'Tête',
    assetPath: 'assets/accessories/headphones_zen.glb',
    sizeRatio: 0.52,
    topRatio: 0.03,
    horizontalOffsetRatio: 0,
  );

  // --- Catégorie Visage (Museau & Yeux) ---

  /// Lunettes Rondes d'Érudit à monture fine dorée.
  static const AccessoryRender glassesRound = AccessoryRender(
    id: 'glasses_round',
    category: 'Visage',
    assetPath: 'assets/accessories/glasses_round.glb',
    sizeRatio: 0.36,
    topRatio: 0.22,
    horizontalOffsetRatio: 0,
  );

  /// Fleur de Cerisier délicate au coin des lèvres.
  static const AccessoryRender flowerMouth = AccessoryRender(
    id: 'flower_mouth',
    category: 'Visage',
    assetPath: 'assets/accessories/flower_mouth.glb',
    sizeRatio: 0.22,
    topRatio: 0.32,
    horizontalOffsetRatio: 0.14,
  );

  /// Tous les accessoires du catalogue ordonnés par priorité visuelle de rendu.
  static const List<AccessoryRender> all = [
    // Habillage en premier (sous le menton)
    scarfCozy,
    bowtieChic,
    zenNecklace,
    // Tête au sommet
    custom1,
    crownLaurel,
    headphonesZen,
    // Visage au premier plan
    glassesRound,
    flowerMouth,
  ];

  /// Récupère le rendu d'un accessoire par son identifiant.
  static AccessoryRender? getById(String id) {
    for (final accessory in all) {
      if (accessory.id == id) return accessory;
    }
    return null;
  }
}

/// Widget réutilisable affichant la mascotte Elyrii avec son Esprit 3D natif
/// (`variantName`) et sa garde-robe d'accessoires équipés multi-catégories.
class MascotWithAccessories extends StatefulWidget {
  /// Configuration du viewer 3D (caméra, rotation, interaction).
  final Mascot3DConfig config;

  /// Largeur de la zone d'affichage.
  final double width;

  /// Hauteur de la zone d'affichage.
  final double height;

  /// Contrôleur externe optionnel pour piloter le modèle 3D.
  final MascotModelController? controller;

  /// Animation du corps de la mascotte (voir [Mascot3DViewer.animation]).
  final MascotAnimation? animation;
  final int animationTrigger;
  final ValueListenable<double>? breathProgress;

  /// Catégorie active prioritaire (ex. 'Habillage', 'Tête', 'Visage')
  /// permettant d'afficher en priorité l'accessoire de l'onglet en cours.
  final String? activeCategory;

  const MascotWithAccessories({
    super.key,
    required this.config,
    required this.width,
    required this.height,
    this.controller,
    this.animation,
    this.animationTrigger = 0,
    this.breathProgress,
    this.activeCategory,
  });

  @override
  State<MascotWithAccessories> createState() => _MascotWithAccessoriesState();
}

class _MascotWithAccessoriesState extends State<MascotWithAccessories> {
  /// Décalage entre le chargement du corps et le montage de l'accessoire.
  static const _accessoryMountDelay = Duration(milliseconds: 250);

  bool _accessoriesMounted = false;

  void _onBodyLoaded() {
    if (_accessoriesMounted) return;
    // Petit délai après le chargement du corps : les deux contextes WebGL
    // ne s'initialisent jamais dans la même frame.
    Future.delayed(_accessoryMountDelay, () {
      if (mounted && !_accessoriesMounted) {
        setState(() => _accessoriesMounted = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.select<MascotProvider, MascotTheme>(
      (p) => p.currentTheme,
    );
    final cosmetics = context.select<MascotProvider, List<String>>(
      (p) => p.mascot.equippedCosmetics,
    );

    // Sélection de l'accessoire rendu : priorité à la catégorie active
    // consultée par l'utilisateur, sinon le dernier équipé (ou premier disponible).
    // Borné à un contexte WebGL additionnel maximum pour préserver la stabilité
    // GPU du corps principal de la mascotte.
    final allRenders = cosmetics
        .map(MascotAccessoryCatalog.getById)
        .whereType<AccessoryRender>()
        .toList();

    final equippedRender = (widget.activeCategory != null
            ? allRenders
                .where((r) => r.category == widget.activeCategory)
                .firstOrNull
            : null) ??
        allRenders.lastOrNull;

    // Scène 3D unifiée (Option A) : tous les accessoires sont intégrés
    // dans le graphe de scène du modèle et attachés aux os du squelette.
    // Un seul contexte WebGL est utilisé : zéro timeout, zéro superposition hasardeuse,
    // occlusion 3D parfaite et support de multiples accessoires simultanés.
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Mascot3DViewer(
        key: const ValueKey('mascot_body_unified'),
        config: widget.config,
        width: widget.width,
        height: widget.height,
        controller: widget.controller,
        colorMatrix: theme.colorMatrix,
        colorTint: theme.id == 'nature' ? null : theme.paletteColors.first,
        variantName: theme.variantName,
        animation: widget.animation,
        animationTrigger: widget.animationTrigger,
        breathProgress: widget.breathProgress,
        visibleAccessories: cosmetics,
        showFallbackImage: false,
        onModelLoaded: _onBodyLoaded,
      ),
    );
  }
}
