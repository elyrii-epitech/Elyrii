// iOS 26 Liquid Glass Card
// Part of the Liquid Glass Widget Kit

import 'package:flutter/material.dart';
import '../../design_system/haptics/elyrii_haptics.dart';
import '../../glass/elyrii_glass_surface.dart';

class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double borderRadius;
  final Color? color;
  final Color? borderColor;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.borderRadius = 20,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ElyriiGlassSurface(
      role: GlassRole.floatingControl,
      borderRadius: BorderRadius.circular(borderRadius),
      padding: padding ?? const EdgeInsets.all(16),
      glassColor: color,
      border: borderColor == null
          ? null
          : Border.all(color: borderColor!, width: 0.5),
      onTap: onTap == null
          ? null
          : () {
              ElyriiHaptics.light();
              onTap?.call();
            },
      child: child,
    );
  }
}
