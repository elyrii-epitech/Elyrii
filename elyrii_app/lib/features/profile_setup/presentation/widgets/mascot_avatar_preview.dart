import 'package:flutter/material.dart';

import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/config/mascot_animations.dart';
import '../../../../core/widgets/mascot_contact_shadow.dart';
import '../../../../core/widgets/mascot_with_accessories.dart';

/// Aperçu fidèle de la mascotte 3D (thème actif + accessoires équipés)
/// avec son ombre de contact au sol.
///
/// Remplace l'ancien aperçu PNG 2D (`assets/mascotte.png`) aux couleurs
/// décalées dans l'onboarding et le sélecteur d'avatar : le rendu WebGL
/// respire via son placeholder chaud puis fond en douceur (géré par le
/// viewer core), sans barre de progression ni pop-in.
class MascotAvatarPreview extends StatelessWidget {
  /// Largeur de la zone de rendu de la mascotte.
  final double width;

  /// Hauteur de la zone de rendu de la mascotte.
  final double height;

  /// Assombrit l'ombre de contact en mode sombre.
  final bool isDark;

  /// Clip joué une fois le modèle chargé (ex. [MascotAnimations.greet]
  /// pour l'écran de bienvenue). Null = idle.
  final MascotAnimation? animation;

  const MascotAvatarPreview({
    super.key,
    required this.width,
    required this.height,
    required this.isDark,
    this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      // Marge sous la mascotte pour que l'ombre de contact respire
      // sans être rognée par le parent.
      height: height + 16,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // Ombre d'occlusion ambiante au sol : mascotte posée (elevation 0),
          // ombre serrée et marquée — ancrage physique sans cage circulaire.
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: MascotContactShadow(
              width: width * 0.6,
              elevation: 0,
              isDark: isDark,
            ),
          ),
          MascotWithAccessories(
            config: const Mascot3DConfig(
              interactionEnabled: false,
              showLoadingIndicator: true,
            ),
            width: width,
            height: height,
            animation: animation,
          ),
        ],
      ),
    );
  }
}
