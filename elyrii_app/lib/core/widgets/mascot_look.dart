import 'package:flutter/foundation.dart';

import '../../features/mascot/data/models/mascot_appearance.dart';
import '../config/mascot_3d_config.dart';

/// Everything the mascot canvas shows at rest: material look, fitted
/// accessory and camera framing. Equal looks render the same pixels.
@immutable
final class MascotLook {
  const MascotLook({
    this.appearance = MascotAppearance.defaults,
    this.accessoryVariant,
    this.cameraOrbit,
    this.cameraTarget,
  });

  MascotLook.framed(
    Mascot3DConfig config, {
    this.appearance = MascotAppearance.defaults,
    this.accessoryVariant,
  }) : cameraOrbit = config.useCameraOrbit
           ? '${config.cameraOrbitTheta}deg ${config.cameraOrbitPhi}deg '
                 '${config.cameraOrbitRadius}%'
           : null,
       cameraTarget = switch (config.cameraTargetY) {
         final y? => '0m ${y}m 0m',
         null => null,
       };

  final MascotAppearance appearance;
  final String? accessoryVariant;

  /// model-viewer `camera-orbit`; null keeps its automatic framing.
  final String? cameraOrbit;

  /// model-viewer `camera-target`; null keeps its automatic framing.
  final String? cameraTarget;

  /// Canonical form: colors in [MascotColorPart] order, so equal looks
  /// always serialize to the same text.
  Map<String, Object?> toJson() => {
    'colors': {
      for (final part in MascotColorPart.values)
        part.name: ?appearance.colors[part.name],
    },
    'finish': appearance.finish.name,
    'variant': accessoryVariant,
    'orbit': cameraOrbit,
    'target': cameraTarget,
  };

  @override
  bool operator ==(Object other) =>
      other is MascotLook &&
      other.appearance == appearance &&
      other.accessoryVariant == accessoryVariant &&
      other.cameraOrbit == cameraOrbit &&
      other.cameraTarget == cameraTarget;

  @override
  int get hashCode =>
      Object.hash(appearance, accessoryVariant, cameraOrbit, cameraTarget);
}
