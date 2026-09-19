import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, ValueListenable;
import 'package:flutter/material.dart';
import 'mascot_model_surface.dart';
import 'package:provider/provider.dart';
import '../config/mascot_3d_config.dart';
import '../config/mascot_themes.dart';
import 'mascot_3d_viewer.dart';
import '../config/mascot_animations.dart';
import '../../features/mascot/presentation/providers/mascot_provider.dart';

/// A single scene/WebView for the body and its equipped accessory.
/// The accessory is attached to the animated head in the generated glTF.
class MascotWithAccessories extends StatelessWidget {
  final Mascot3DConfig config;
  final double width;
  final double height;
  final MascotModelController? controller;
  final MascotAnimation? animation;
  final int animationTrigger;
  final ValueListenable<double>? breathProgress;

  const MascotWithAccessories({
    super.key,
    required this.config,
    required this.width,
    required this.height,
    this.controller,
    this.animation,
    this.animationTrigger = 0,
    this.breathProgress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.select<MascotProvider, MascotTheme>(
      (p) => p.currentTheme,
    );
    final graduate = context.select<MascotProvider, bool>(
      (p) => p.mascot.equippedCosmetics.contains('custom1'),
    );
    final matrix = (theme.id == 'nature' || (!kIsWeb && Platform.isIOS))
        ? null
        : theme.colorMatrix;
    return Mascot3DViewer(
      key: const ValueKey('mascot_body'),
      config: graduate
          ? config.copyWith(assetPath: 'assets/optimized/mascot_graduate.glb')
          : config,
      width: width,
      height: height,
      controller: controller,
      colorMatrix: matrix,
      animation: animation,
      animationTrigger: animationTrigger,
      breathProgress: breathProgress,
    );
  }
}
