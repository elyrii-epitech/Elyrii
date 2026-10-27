import 'package:flutter/material.dart';

import 'liquid_glass_button.dart';

/// Shared app back button: an iOS arrow in a 48-pixel Liquid Glass button,
/// identical across pages. Uses `Navigator.pop` when [onPressed] is absent.
class ElyriiBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? color;

  const ElyriiBackButton({super.key, this.onPressed, this.color});

  @override
  Widget build(BuildContext context) {
    return LiquidGlassIconButton(
      tooltip: 'Retour',
      icon: Icons.arrow_back_ios_new_rounded,
      size: 48,
      color: color,
      onPressed: onPressed ?? () => Navigator.of(context).pop(),
    );
  }
}
