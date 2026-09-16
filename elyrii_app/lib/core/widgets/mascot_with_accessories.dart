import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:provider/provider.dart';
import '../config/mascot_3d_config.dart';
import '../config/mascot_themes.dart';
import 'mascot_3d_viewer.dart';
import '../config/mascot_animations.dart';
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
///
/// Montage progressif : le viewer du corps démarre toujours en premier ; le
/// viewer de l'accessoire ne monte qu'après le chargement du corps (plus un
/// court délai) pour que deux contextes WebGL ne s'initialisent jamais
/// simultanément — principal point de jank sur iOS.
///
/// Usage :
/// ```dart
/// MascotWithAccessories(
///   config: const Mascot3DConfig.chatbotFull(),
///   width: 250,
///   height: 250,
/// )
/// ```
class MascotWithAccessories extends StatefulWidget {
  /// Configuration du viewer 3D (caméra, rotation, interaction).
  final Mascot3DConfig config;

  /// Largeur de la zone d'affichage.
  final double width;

  /// Hauteur de la zone d'affichage.
  final double height;

  /// Contrôleur externe optionnel pour piloter le modèle 3D.
  final Flutter3DController? controller;

  /// Animation du corps de la mascotte (voir [Mascot3DViewer.animation]).
  final MascotAnimation? animation;

  const MascotWithAccessories({
    super.key,
    required this.config,
    required this.width,
    required this.height,
    this.controller,
    this.animation,
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

    // Le thème par ColorMatrix n'est appliqué que si la plateforme le supporte.
    // Sur iOS, ColorFiltered sur un PlatformView (WKWebView) rend la texture
    // CVPixelBuffer transparente (limitation connue du rasterizer Flutter iOS).
    // On désactive ColorFiltered sur iOS pour que la mascotte 3D reste TOUJOURS visible.
    final matrix = (theme.id == 'nature' || (!kIsWeb && Platform.isIOS))
        ? null
        : theme.colorMatrix;
    // Un seul accessoire rendu (premier équipé dans l'ordre du catalogue) :
    // borné à un contexte WebGL additionnel maximum en attendant un asset
    // pré-fusionné corps+accessoire.
    final equippedRender = cosmetics
        .map(MascotAccessoryCatalog.getById)
        .whereType<AccessoryRender>()
        .firstOrNull;

    final body = Mascot3DViewer(
      key: const ValueKey('mascot_body'),
      config: widget.config,
      width: widget.width,
      height: widget.height,
      controller: widget.controller,
      colorMatrix: matrix,
      animation: widget.animation,
      onModelLoaded: _onBodyLoaded,
    );

    if (equippedRender == null || !_accessoriesMounted) {
      return SizedBox(width: widget.width, height: widget.height, child: body);
    }

    final accessorySize = widget.width * equippedRender.sizeRatio;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          body,
          Positioned(
            top: widget.height * equippedRender.topRatio,
            left:
                (widget.width - accessorySize) / 2 +
                widget.width * equippedRender.horizontalOffsetRatio,
            child: Mascot3DViewer(
              key: ValueKey('mascot_accessory_${equippedRender.id}'),
              config: Mascot3DConfig(
                assetPath: equippedRender.assetPath,
                autoRotate: false,
                interactionEnabled: false,
              ),
              width: accessorySize,
              height: accessorySize,
            ),
          ),
        ],
      ),
    );
  }
}
