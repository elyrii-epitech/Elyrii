import 'package:flutter/material.dart';

import '../design_system/haptics/elyrii_haptics.dart';
import '../glass/elyrii_glass_surface.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_motion.dart';

/// Bouton en forme de bulle avec effet iOS 26 Liquid Glass
/// Peut être réutilisé pour chatbot, settings, notifications, etc.
class GlassBubbleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final double size;
  final bool isDark;
  final bool isSelected;
  final String? tooltip;

  /// Full-color avatar, cropped to the mockup's circular chat image.
  final String? iconAsset;
  final double iconAssetSize;

  const GlassBubbleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.size = 64,
    this.isDark = false,
    this.isSelected = false,
    this.tooltip,
    this.iconAsset,
    this.iconAssetSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final tint =
        iconColor ??
        (isSelected
            ? (isDark ? AppColors.primaryDark : AppColors.primary)
            : (isDark
                  ? AppColors.iconDefaultDark
                  : AppColors.iconDefaultLight));
    final Widget buttonContent = ElyriiGlassSurface(
      role: GlassRole.navigation,
      lifted: true,
      borderRadius: BorderRadius.circular(size / 2),
      width: size,
      height: size,
      border: isSelected
          ? Border.all(color: tint, width: AppDimensions.borderWidthMedium)
          : null,
      child: Center(
        child: iconAsset != null
            ? ClipOval(
                child: Image.asset(
                  iconAsset!,
                  width: iconAssetSize,
                  height: iconAssetSize,
                  fit: BoxFit.cover,
                ),
              )
            : Icon(icon, size: 26, color: tint),
      ),
    );

    return _GlassBubbleInteraction(
      onTap: onTap,
      selected: isSelected,
      label: tooltip,
      reduceMotion: media.disableAnimations,
      focusColor: tint,
      child: buttonContent,
    );
  }
}

/// Widget stateful qui gère l'état de pression pour GlassBubbleButton
class GlassBubbleButtonStateful extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool isDark;
  final bool isSelected;
  final String? tooltip;
  final String? iconAsset;
  final double iconAssetSize;

  const GlassBubbleButtonStateful({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 64,
    this.isDark = false,
    this.isSelected = false,
    this.tooltip,
    this.iconAsset,
    this.iconAssetSize = 28,
  });

  @override
  State<GlassBubbleButtonStateful> createState() =>
      _GlassBubbleButtonStatefulState();
}

class _GlassBubbleButtonStatefulState extends State<GlassBubbleButtonStateful> {
  @override
  Widget build(BuildContext context) {
    return GlassBubbleButton(
      icon: widget.icon,
      onTap: widget.onTap,
      size: widget.size,
      isDark: widget.isDark,
      isSelected: widget.isSelected,
      tooltip: widget.tooltip,
      iconAsset: widget.iconAsset,
      iconAssetSize: widget.iconAssetSize,
    );
  }
}

/// One interaction target for touch, keyboard and assistive technologies.
class _GlassBubbleInteraction extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool selected;
  final String? label;
  final bool reduceMotion;
  final Color focusColor;

  const _GlassBubbleInteraction({
    required this.child,
    required this.onTap,
    required this.selected,
    required this.label,
    required this.reduceMotion,
    required this.focusColor,
  });

  @override
  State<_GlassBubbleInteraction> createState() =>
      _GlassBubbleInteractionState();
}

class _GlassBubbleInteractionState extends State<_GlassBubbleInteraction> {
  bool _isPressed = false;
  bool _showFocus = false;

  void _activate() {
    ElyriiHaptics.light();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    Widget control = Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      selected: widget.selected,
      label: widget.label,
      onTap: _activate,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
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
          onTap: _activate,
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedScale(
            scale: _isPressed && !widget.reduceMotion ? 0.96 : 1.0,
            duration: widget.reduceMotion
                ? Duration.zero
                : AppMotion.dockBubblePress,
            curve: AppMotion.dockPressCurve,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: _showFocus
                    ? Border.all(color: widget.focusColor, width: 2)
                    : null,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
    if (widget.label != null) {
      control = Tooltip(message: widget.label!, child: control);
    }
    return control;
  }
}
