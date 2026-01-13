// iOS 26 Liquid Glass Toast
// Part of the Liquid Glass Widget Kit

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';

/// Shows an iOS 26 style toast notification
void showLiquidGlassToast({
  required BuildContext context,
  required String message,
  IconData? icon,
  Duration duration = const Duration(seconds: 2),
  Color? backgroundColor,
}) {
  HapticFeedback.lightImpact();

  final overlay = Overlay.of(context);
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => LiquidGlassToast(
      message: message,
      icon: icon,
      backgroundColor: backgroundColor,
      onDismiss: () => overlayEntry.remove(),
      duration: duration,
    ),
  );

  overlay.insert(overlayEntry);
}

class LiquidGlassToast extends StatefulWidget {
  final String message;
  final IconData? icon;
  final Color? backgroundColor;
  final VoidCallback onDismiss;
  final Duration duration;

  const LiquidGlassToast({
    super.key,
    required this.message,
    this.icon,
    this.backgroundColor,
    required this.onDismiss,
    required this.duration,
  });

  @override
  State<LiquidGlassToast> createState() => _LiquidGlassToastState();
}

class _LiquidGlassToastState extends State<LiquidGlassToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: AppDimensions.blurSigmaLiquidGlass,
                sigmaY: AppDimensions.blurSigmaLiquidGlass,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: widget.backgroundColor ??
                      (isDark
                          ? AppColors.liquidGlassBackgroundDark
                          : AppColors.liquidGlassBackgroundLight),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? AppColors.liquidGlassBorderDark
                        : AppColors.liquidGlassBorderLight,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    if (widget.icon != null) ...[
                      Icon(
                        widget.icon,
                        size: 22,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
