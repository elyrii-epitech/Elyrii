import 'package:flutter/material.dart';

import '../../../../core/widgets/glass/liquid_glass_button.dart';

/// Shared keyboard, semantics, hit target and reduced-motion behavior.
class GlassSettingsButton extends StatelessWidget {
  const GlassSettingsButton({
    super.key,
    required this.onTap,
    this.isDark = false,
  });

  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) => LiquidGlassIconButton(
    icon: Icons.settings_rounded,
    tooltip: 'Paramètres',
    onPressed: onTap,
    size: 44,
    color: isDark ? Colors.white : Colors.black,
  );
}
