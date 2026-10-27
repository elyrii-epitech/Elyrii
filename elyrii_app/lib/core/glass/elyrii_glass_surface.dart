import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../widgets/accessible_action.dart';
import 'glass_role.dart';

export 'glass_role.dart';

final _navigationFilter = ui.ImageFilter.compose(
  outer: ColorFilter.saturation(AppDimensions.navigationSaturation),
  inner: ui.ImageFilter.blur(
    sigmaX: AppDimensions.navigationBlur,
    sigmaY: AppDimensions.navigationBlur,
  ),
);

/// Unified, efficient Liquid Glass primitive for Elyrii. Wraps [GlassContainer]
/// from `liquid_glass_widgets`, rendering opaquely in high contrast.
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

  /// Navigation only: denser fill, brighter hairline and a soft drop shadow,
  /// for floating controls that must stand out from the content below.
  final bool lifted;

  const ElyriiGlassSurface({
    super.key,
    required this.child,
    required this.role,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(AppDimensions.radius20),
    ),
    this.padding,
    this.glassColor,
    this.border,
    this.onTap,
    this.width,
    this.height,
    this.lightweight = false,
    this.lifted = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    // La surface v2 est translucide : le repli opaque la compose sur le fond
    // pour garder son rendu sans alpha.
    final surface = Color.alphaBlend(
      isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
    );
    final shouldFallback = lightweight || highContrast;

    if (role == GlassRole.navigation) {
      final tint =
          glassColor ??
          (lifted
              ? AppColors.liftedGlass(isDark)
              : isDark
              ? AppColors.glassBackgroundDark
              : AppColors.glassBackgroundLight);
      Widget content = RepaintBoundary(
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            enabled: !shouldFallback,
            filter: _navigationFilter,
            child: Container(
              width: width,
              height: height,
              padding: padding,
              decoration: BoxDecoration(
                color: highContrast
                    ? Color.alphaBlend(tint, surface).withValues(alpha: 1)
                    : tint,
                borderRadius: borderRadius,
                border:
                    border ??
                    Border.all(
                      color: lifted
                          ? AppColors.liftedGlassStroke(isDark)
                          : isDark
                          ? AppColors.glassBorderDark
                          : AppColors.glassBorderLight,
                      width: AppDimensions.glassStroke,
                    ),
              ),
              child: child,
            ),
          ),
        ),
      );
      if (lifted && !highContrast) {
        content = DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: AppColors.liftedGlassShadow(isDark),
          ),
          child: content,
        );
      }
      if (onTap != null) {
        content = AccessibleAction(
          label: null,
          onPressed: onTap,
          borderRadius: borderRadius,
          child: content,
        );
      }
      return content;
    }

    // Opaque fallback for the platform accessibility contrast setting.
    if (shouldFallback) {
      Widget content = Container(
        width: width,
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: highContrast
              ? Color.alphaBlend(
                  glassColor ?? surface,
                  surface,
                ).withValues(alpha: 1)
              : glassColor ?? surface,
          borderRadius: borderRadius,
          border:
              border ??
              Border.all(
                color: isDark
                    ? AppColors.glassBorderDark
                    : AppColors.glassBorderLight,
                width: 1.0,
              ),
        ),
        child: child,
      );

      if (onTap != null) {
        content = AccessibleAction(
          label: null,
          onPressed: onTap,
          borderRadius: borderRadius,
          child: content,
        );
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
                  ? AppColors.glassBorderDark
                  : AppColors.glassBorderLight,
            ),
      ),
      child: glass,
    );

    Widget content = RepaintBoundary(child: glass);

    if (onTap != null) {
      content = AccessibleAction(
        label: null,
        onPressed: onTap,
        borderRadius: borderRadius,
        child: content,
      );
    }
    return content;
  }
}
