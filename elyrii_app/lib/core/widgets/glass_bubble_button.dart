import 'package:flutter/material.dart';
import '../design_system/haptics/elyrii_haptics.dart';
import '../glass/elyrii_glass_surface.dart';
import '../theme/app_colors.dart';

/// Bouton en forme de bulle avec effet iOS 26 Liquid Glass
/// Peut être réutilisé pour chatbot, settings, notifications, etc.
class GlassBubbleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final double size;
  final bool isDark;
  final bool isSelected;

  /// Asset monochrome optionnel : affiché à la place de [icon], teinté
  /// comme une icône Material (masque alpha) pour respecter la DA.
  final String? iconAsset;

  const GlassBubbleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.size = 64,
    this.isDark = false,
    this.isSelected = false,
    this.iconAsset,
  });

  @override
  Widget build(BuildContext context) {
    final tint =
        iconColor ??
        (isSelected
            ? AppColors.primary
            : (isDark
                  ? AppColors.iconDefaultDark
                  : AppColors.iconDefaultLight));
    final Widget buttonContent = ElyriiGlassSurface(
      role: GlassRole.floatingControl,
      borderRadius: BorderRadius.circular(size / 2),
      width: size,
      height: size,
      glassColor: isSelected
          ? AppColors.primary.withValues(alpha: isDark ? 0.24 : 0.15)
          : null,
      child: Center(
        child: iconAsset != null
            ? ImageIcon(
                AssetImage(iconAsset!),
                size: 28,
                color: tint,
              )
            : Icon(
                icon,
                size: 26,
                color: tint,
              ),
      ),
    );

    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: buttonContent,
      ),
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

  const GlassBubbleButtonStateful({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 64,
    this.isDark = false,
    this.isSelected = false,
    this.tooltip,
    this.iconAsset,
  });

  @override
  State<GlassBubbleButtonStateful> createState() =>
      _GlassBubbleButtonStatefulState();
}

class _GlassBubbleButtonStatefulState extends State<GlassBubbleButtonStateful> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          setState(() => _isPressed = true);
          ElyriiHaptics.light();
        },
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: GlassBubbleButton(
            icon: widget.icon,
            onTap: widget.onTap,
            size: widget.size,
            isDark: widget.isDark,
            isSelected: widget.isSelected,
            iconColor: null,
            iconAsset: widget.iconAsset,
          ),
        ),
      ),
    );
  }
}
