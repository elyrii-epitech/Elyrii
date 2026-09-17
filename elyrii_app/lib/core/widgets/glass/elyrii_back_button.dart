import 'package:flutter/material.dart';

import 'liquid_glass_button.dart';

/// Bouton retour unifié de l'application : flèche iOS dans un bouton
/// Liquid Glass de 44 px, identique sur toutes les pages.
///
/// Sans [onPressed], exécute `Navigator.pop`.
class ElyriiBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? color;

  const ElyriiBackButton({super.key, this.onPressed, this.color});

  @override
  Widget build(BuildContext context) {
    return LiquidGlassIconButton(
      icon: Icons.arrow_back_ios_new_rounded,
      size: 44,
      color: color,
      onPressed: onPressed ?? () => Navigator.of(context).pop(),
    );
  }
}
