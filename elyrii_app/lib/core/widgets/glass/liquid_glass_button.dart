// iOS 26 Liquid Glass Buttons
// Part of the Liquid Glass Widget Kit

import 'package:flutter/material.dart';
import '../../design_system/haptics/elyrii_haptics.dart';
import '../../glass/elyrii_glass_surface.dart';

enum LiquidGlassButtonStyle { filled, tinted, plain, gray }

class LiquidGlassButton extends StatefulWidget {
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
  State<LiquidGlassButton> createState() => _LiquidGlassButtonState();
}

class _LiquidGlassButtonState extends State<LiquidGlassButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final isDisabled = widget.onPressed == null;

    Color backgroundColor;
    Color textColor;

    switch (widget.style) {
      case LiquidGlassButtonStyle.filled:
        backgroundColor = isDisabled
            ? primaryColor.withValues(alpha: 0.3)
            : primaryColor;
        textColor = Colors.white;
        break;
      case LiquidGlassButtonStyle.tinted:
        backgroundColor = primaryColor.withValues(alpha: 0.15);
        textColor = isDisabled
            ? primaryColor.withValues(alpha: 0.5)
            : primaryColor;
        break;
      case LiquidGlassButtonStyle.plain:
        backgroundColor = Colors.transparent;
        textColor = isDisabled
            ? primaryColor.withValues(alpha: 0.5)
            : primaryColor;
        break;
      case LiquidGlassButtonStyle.gray:
        backgroundColor = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05);
        textColor = isDark ? Colors.white : Colors.black;
        if (isDisabled) {
          textColor = textColor.withValues(alpha: 0.4);
        }
        break;
    }

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => setState(() => _isPressed = true),
      onTapUp: isDisabled ? null : (_) => setState(() => _isPressed = false),
      onTapCancel: isDisabled ? null : () => setState(() => _isPressed = false),
      onTap: isDisabled || widget.isLoading
          ? null
          : () {
              ElyriiHaptics.light();
              widget.onPressed?.call();
            },
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _isPressed ? 0.7 : 1.0,
          child: ElyriiGlassSurface(
            role: GlassRole.floatingControl,
            borderRadius: BorderRadius.circular(12),
            width: widget.isExpanded ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            glassColor: backgroundColor,
            child: widget.isExpanded
                ? Center(child: _buildContent(textColor))
                : _buildContent(textColor),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Color textColor) {
    if (widget.isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(textColor),
        ),
      );
    }

    return Row(
      mainAxisSize: widget.isExpanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 20, color: textColor),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class LiquidGlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final Color? backgroundColor;

  const LiquidGlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 44,
    this.color,
    this.backgroundColor,
  });

  @override
  State<LiquidGlassIconButton> createState() => _LiquidGlassIconButtonState();
}

class _LiquidGlassIconButtonState extends State<LiquidGlassIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDisabled = widget.onPressed == null;
    final button = ElyriiGlassSurface(
      role: GlassRole.floatingControl,
      borderRadius: BorderRadius.circular(widget.size / 2),
      width: widget.size,
      height: widget.size,
      glassColor: widget.backgroundColor,
      child: Icon(
        widget.icon,
        size: widget.size * 0.5,
        color:
            widget.color ??
            (isDark ? Colors.white : Colors.black.withValues(alpha: 0.8)),
      ),
    );

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => setState(() => _isPressed = true),
      onTapUp: isDisabled ? null : (_) => setState(() => _isPressed = false),
      onTapCancel: isDisabled ? null : () => setState(() => _isPressed = false),
      onTap: isDisabled
          ? null
          : () {
              ElyriiHaptics.light();
              widget.onPressed?.call();
            },
      child: AnimatedScale(
        scale: _isPressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _isPressed ? 0.6 : (isDisabled ? 0.4 : 1.0),
          child: RepaintBoundary(child: button),
        ),
      ),
    );
  }
}
