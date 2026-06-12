// iOS 26 Liquid Glass Buttons
// Part of the Liquid Glass Widget Kit

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/glass_performance_service.dart';
import '../../theme/app_dimensions.dart';

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
        backgroundColor =
            isDisabled ? primaryColor.withValues(alpha: 0.3) : primaryColor;
        textColor = Colors.white;
        break;
      case LiquidGlassButtonStyle.tinted:
        backgroundColor = primaryColor.withValues(alpha: 0.15);
        textColor =
            isDisabled ? primaryColor.withValues(alpha: 0.5) : primaryColor;
        break;
      case LiquidGlassButtonStyle.plain:
        backgroundColor = Colors.transparent;
        textColor =
            isDisabled ? primaryColor.withValues(alpha: 0.5) : primaryColor;
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
              HapticFeedback.lightImpact();
              widget.onPressed?.call();
            },
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _isPressed ? 0.7 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
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
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: textColor,
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
    final blurSigma = GlassPerformanceService().getEffectiveBlurSigma(
      AppDimensions.blurSigmaLiquidGlass,
    );
    final button = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: 0.12),
                  Colors.white.withValues(alpha: 0.07),
                ]
              : [
                  Colors.white.withValues(alpha: 0.85),
                  Colors.white.withValues(alpha: 0.72),
                ],
        ),
        borderRadius: BorderRadius.circular(widget.size / 2),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.black.withValues(alpha: 0.06),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark ? 0.22 : 0.08,
            ),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(
        widget.icon,
        size: widget.size * 0.5,
        color: widget.color ??
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
              HapticFeedback.lightImpact();
              widget.onPressed?.call();
            },
      child: AnimatedScale(
        scale: _isPressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _isPressed ? 0.6 : (isDisabled ? 0.4 : 1.0),
          child: RepaintBoundary(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.size / 2),
              child: blurSigma > 0
                  ? BackdropFilter(
                      filter: ImageFilter.blur(
                          sigmaX: blurSigma, sigmaY: blurSigma),
                      child: button,
                    )
                  : button,
            ),
          ),
        ),
      ),
    );
  }
}
