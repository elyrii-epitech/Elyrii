import 'package:flutter/material.dart';

import '../accessible_action.dart';
import '../../glass/elyrii_glass_surface.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_text_styles.dart';

enum LiquidGlassButtonStyle { filled, tinted, plain, gray }

class LiquidGlassButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final LiquidGlassButtonStyle style;
  final bool isExpanded;
  final bool isLoading;

  const LiquidGlassButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.style = LiquidGlassButtonStyle.filled,
    this.isExpanded = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final isDisabled = onPressed == null;
    final primary = scheme.primary;
    final (background, foreground) = switch (style) {
      LiquidGlassButtonStyle.filled => (
        primary.withValues(alpha: isDisabled ? 0.3 : 1),
        isDisabled ? scheme.onSurface.withValues(alpha: 0.5) : scheme.onPrimary,
      ),
      LiquidGlassButtonStyle.tinted => (
        primary.withValues(alpha: 0.15),
        primary.withValues(alpha: isDisabled ? 0.5 : 1),
      ),
      LiquidGlassButtonStyle.plain => (
        Colors.transparent,
        primary.withValues(alpha: isDisabled ? 0.5 : 1),
      ),
      LiquidGlassButtonStyle.gray => (
        scheme.onSurface.withValues(alpha: isDark ? 0.1 : 0.05),
        scheme.onSurface.withValues(alpha: isDisabled ? 0.4 : 1),
      ),
    };
    final radius = BorderRadius.circular(AppDimensions.radiusMd);
    return AccessibleAction(
      label: label,
      onPressed: isLoading ? null : onPressed,
      borderRadius: radius,
      child: ElyriiGlassSurface(
        role: GlassRole.floatingControl,
        borderRadius: radius,
        width: isExpanded ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        glassColor: background,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 20),
          child: isLoading
              ? Center(
                  widthFactor: isExpanded ? null : 1,
                  heightFactor: 1,
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  ),
                )
              : Row(
                  mainAxisSize: isExpanded
                      ? MainAxisSize.max
                      : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: AppDimensions.iconSm, color: foreground),
                      const SizedBox(width: AppDimensions.spacingXs),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        style: AppTextStyles.button().copyWith(
                          color: foreground,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class LiquidGlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final Color? backgroundColor;
  final String tooltip;

  const LiquidGlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 44,
    this.color,
    this.backgroundColor,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size / 2);
    final tint = color ?? Theme.of(context).colorScheme.onSurface;
    final button = AccessibleAction(
      label: tooltip,
      onPressed: onPressed,
      borderRadius: radius,
      child: ElyriiGlassSurface(
        role: GlassRole.floatingControl,
        borderRadius: radius,
        width: size,
        height: size,
        glassColor: backgroundColor,
        child: Center(
          child: Icon(
            icon,
            size: size * 0.5,
            color: onPressed == null ? tint.withValues(alpha: 0.4) : tint,
          ),
        ),
      ),
    );
    return Tooltip(message: tooltip, excludeFromSemantics: true, child: button);
  }
}
