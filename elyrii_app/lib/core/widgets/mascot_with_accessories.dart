import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'mascot_model_surface.dart';

import 'package:provider/provider.dart';

import '../config/mascot_3d_config.dart';
import '../config/mascot_themes.dart';
import 'mascot_3d_viewer.dart';
import '../config/mascot_animations.dart';
import '../../features/mascot/presentation/providers/mascot_provider.dart';
import '../../features/mascot/data/models/mascot_accessory.dart';
import '../../features/mascot/data/models/mascot_model.dart';
import '../../features/mascot/data/models/mascot_appearance.dart';

/// One rigged scene for the bear and its wardrobe. Material variants switch
/// accessories while the same head/chest controls continue to animate.
class MascotWithAccessories extends StatelessWidget {
  final Mascot3DConfig config;
  final double width;
  final double height;
  final MascotModelController? controller;
  final MascotAnimation? animation;
  final int animationTrigger;
  final ValueListenable<double>? breathProgress;
  final MascotModel? mascot;

  const MascotWithAccessories({
    super.key,
    required this.config,
    required this.width,
    required this.height,
    this.controller,
    this.animation,
    this.animationTrigger = 0,
    this.breathProgress,
    this.mascot,
  });

  @override
  Widget build(BuildContext context) {
    final model =
        mascot ?? context.select<MascotProvider, MascotModel>((p) => p.mascot);
    final appearance = MascotAppearance(
      colors: Map.unmodifiable({
        ...MascotThemes.colorsFor(model.themeId),
        ...model.appearance.colors,
      }),
      finish: model.appearance.finish,
    );
    return Mascot3DViewer(
      key: const ValueKey('mascot_body'),
      config: config.copyWith(
        assetPath: 'assets/optimized/mascot_wardrobe.glb',
      ),
      accessoryVariant: MascotAccessories.variantFor(model.equippedCosmetics),
      width: width,
      height: height,
      controller: controller,
      appearance: appearance,
      animation: animation,
      animationTrigger: animationTrigger,
      breathProgress: breathProgress,
    );
  }
}
