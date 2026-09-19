import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../design_system/colors/elyrii_colors.dart';
import 'glass_role.dart';

export 'glass_role.dart';

/// Primitive Liquid Glass unifiée et performante pour Elyrii.
///
/// Encapsule [GlassContainer] de `liquid_glass_widgets` avec un rendu opaque
/// en contraste élevé.
class ElyriiGlassSurface extends StatelessWidget {
  final Widget child;
  final GlassRole role;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final Border? border;
  final Color? glassColor;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  /// List rows already sit inside a glass sheet: avoid another offscreen layer.
  final bool lightweight;

  const ElyriiGlassSurface({
    super.key,
    required this.child,
    required this.role,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.padding,
    this.glassColor,
    this.border,
    this.onTap,
    this.width,
    this.height,
    this.lightweight = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shouldFallback =
        lightweight || (MediaQuery.maybeOf(context)?.highContrast ?? false);

    // Opaque fallback for the platform accessibility contrast setting.
    if (shouldFallback) {
      Widget content = Container(
        width: width,
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color:
              glassColor ??
              (isDark ? ElyriiColors.surfaceDark : ElyriiColors.surfaceLight),
          borderRadius: borderRadius,
          border:
              border ??
              Border.all(
                color: isDark
                    ? ElyriiColors.glassBorderDark
                    : ElyriiColors.glassBorderLight,
                width: 1.0,
              ),
        ),
        child: child,
      );

      if (onTap != null) {
        content = GestureDetector(onTap: onTap, child: content);
      }
      return content;
    }

    // Rendu Liquid Glass accéléré par shader via liquid_glass_widgets
    final radiusValue = borderRadius.topLeft.x;

    Widget glass = GlassContainer(
      width: width,
      height: height,
      padding: padding,
      useOwnLayer: true,
      shape: LiquidRoundedSuperellipse(borderRadius: radiusValue),
      settings: LiquidGlassSettings(
        blur: role.blur,
        refractiveIndex: 1.0 + role.refraction,
        glassColor:
            glassColor ??
            (isDark
                ? const Color(0xFF1A1818).withValues(alpha: role.opacity * 0.75)
                : Colors.white.withValues(alpha: role.opacity)),
        lightIntensity: isDark ? 0.3 : 0.6,
      ),
      child: child,
    );
    // Ombre d'ambiance douce + bordure vitreuse par défaut : la carte se
    // détache du fond avec rondeur au lieu de former un aplat brutal.
    glass = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
            blurRadius: 14,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
        border:
            border ??
            Border.all(
              width: 0.5,
              color: isDark
                  ? ElyriiColors.glassBorderDark
                  : ElyriiColors.glassBorderLight,
            ),
      ),
      child: glass,
    );

    Widget content = RepaintBoundary(child: glass);

    if (onTap != null) {
      content = GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}
