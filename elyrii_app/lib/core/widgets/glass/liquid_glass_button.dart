import 'package:flutter/material.dart';

import '../../design_system/haptics/elyrii_haptics.dart';
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
    return _GlassButtonInteraction(
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
  final String? tooltip;

  const LiquidGlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 44,
    this.color,
    this.backgroundColor,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size / 2);
    final tint = color ?? Theme.of(context).colorScheme.onSurface;
    final button = _GlassButtonInteraction(
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
    return tooltip == null
        ? button
        : Tooltip(message: tooltip!, excludeFromSemantics: true, child: button);
  }
}

/// The same action is available to touch, keyboard and assistive technologies.
class _GlassButtonInteraction extends StatefulWidget {
  const _GlassButtonInteraction({
    required this.label,
    required this.onPressed,
    required this.borderRadius,
    required this.child,
  });

  final String? label;
  final VoidCallback? onPressed;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  State<_GlassButtonInteraction> createState() =>
      _GlassButtonInteractionState();
}

class _GlassButtonInteractionState extends State<_GlassButtonInteraction> {
  bool _isPressed = false;
  bool _showFocus = false;

  void _activate() {
    if (widget.onPressed == null) return;
    ElyriiHaptics.light();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 150);
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: enabled,
      label: widget.label,
      onTap: enabled ? _activate : null,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowFocusHighlight: (value) => setState(() => _showFocus = value),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        child: GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _isPressed = false) : null,
          onTapCancel: enabled
              ? () => setState(() => _isPressed = false)
              : null,
          onTap: enabled ? _activate : null,
          child: AnimatedScale(
            scale: _isPressed && enabled && !reduceMotion ? 0.97 : 1,
            duration: duration,
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              duration: duration,
              opacity: _isPressed && enabled ? 0.7 : 1,
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  border: _showFocus && enabled
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        )
                      : null,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
