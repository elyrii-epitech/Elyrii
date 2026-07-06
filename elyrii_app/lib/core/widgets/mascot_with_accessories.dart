import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:provider/provider.dart';
import '../config/mascot_3d_config.dart';
import '../config/mascot_themes.dart';
import 'mascot_3d_viewer.dart';
import '../../features/mascot/presentation/providers/mascot_provider.dart';

/// Définition de rendu d'un accessoire superposé à la mascotte 3D.
///
/// Chaque accessoire est positionné par ratio par rapport à la taille de la
/// mascotte afin de rester cohérent quelle que soit la dimension d'affichage.
@immutable
class AccessoryRender {
  /// Identifiant correspondant à un cosmétique équipé ([MascotModel.equippedCosmetics]).
  final String id;

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
    required this.assetPath,
    required this.sizeRatio,
    required this.topRatio,
    this.horizontalOffsetRatio = 0,
  });
}

/// Catalogue centralisé des accessoires et de leur rendu visuel.
///
/// Garantit que tous les accessoires équipés s'affichent de la même façon
/// sur toutes les pages de l'application.
class MascotAccessoryCatalog {
  MascotAccessoryCatalog._();

  /// Chapeau de diplômé, posé sur le sommet du crâne.
  static const AccessoryRender custom1 = AccessoryRender(
    id: 'custom1',
    assetPath: 'assets/custom1.glb',
    sizeRatio: 0.46,
    topRatio: 0.0,
    horizontalOffsetRatio: 0,
  );

  /// Tous les accessoires connus, dans l'ordre de superposition.
  static const List<AccessoryRender> all = [custom1];

  /// Récupère le rendu d'un accessoire par son identifiant.
  static AccessoryRender? getById(String id) {
    for (final accessory in all) {
      if (accessory.id == id) return accessory;
    }
    return null;
  }
}

/// Widget réutilisable affichant la mascotte Elyrii avec son thème visuel
/// courant **et** tous ses accessoires équipés.
///
/// Lit automatiquement [MascotProvider] pour appliquer le thème (ColorMatrix)
/// et superposer les accessoires de façon identique sur toutes les pages.
/// Remplace les implémentations dispersées qui oubliaient les accessoires.
///
/// Usage :
/// ```dart
/// MascotWithAccessories(
///   config: const Mascot3DConfig.chatbotFull(),
///   width: 250,
///   height: 250,
/// )
/// ```
class MascotWithAccessories extends StatelessWidget {
  /// Configuration du viewer 3D (caméra, rotation, interaction).
  final Mascot3DConfig config;

  /// Largeur de la zone d'affichage.
  final double width;

  /// Hauteur de la zone d'affichage.
  final double height;

  /// Contrôleur externe optionnel pour piloter le modèle 3D.
  final Flutter3DController? controller;

  const MascotWithAccessories({
    super.key,
    required this.config,
    required this.width,
    required this.height,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.select<MascotProvider, MascotTheme>(
      (p) => p.currentTheme,
    );
    final cosmetics = context.select<MascotProvider, List<String>>(
      (p) => p.mascot.equippedCosmetics,
    );

    // Le thème n'est appliqué qu'au corps, pas aux accessoires (comportement
    // historique : un chapeau garde ses couleurs d'origine).
    final matrix = theme.id == 'nature' ? null : theme.colorMatrix;

    final equippedRenders = cosmetics
        .map(MascotAccessoryCatalog.getById)
        .whereType<AccessoryRender>()
        .toList();

    if (equippedRenders.isEmpty) {
      return Mascot3DViewer(
        key: const ValueKey('mascot_body'),
        config: config,
        width: width,
        height: height,
        controller: controller,
        colorMatrix: matrix,
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Mascot3DViewer(
            key: const ValueKey('mascot_body'),
            config: config,
            width: width,
            height: height,
            controller: controller,
            colorMatrix: matrix,
          ),
          ...equippedRenders.map((accessory) {
            final accessorySize = width * accessory.sizeRatio;
            return Positioned(
              top: height * accessory.topRatio,
              left:
                  (width - accessorySize) / 2 +
                  width * accessory.horizontalOffsetRatio,
              child: Mascot3DViewer(
                key: ValueKey('mascot_accessory_${accessory.id}'),
                config: Mascot3DConfig(
                  assetPath: accessory.assetPath,
                  autoRotate: false,
                  interactionEnabled: false,
                  showLoadingIndicator: false,
                ),
                width: accessorySize,
                height: accessorySize,
              ),
            );
          }),
        ],
      ),
    );
  }
}
