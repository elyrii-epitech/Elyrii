// iOS 26 Liquid Glass Sheet
// Part of the Liquid Glass Widget Kit

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';

/// Shows an iOS 26 style bottom sheet with liquid glass effect
Future<T?> showLiquidGlassSheet<T>({
  required BuildContext context,
  required Widget child,
  double initialChildSize = 0.5,
  double minChildSize = 0.25,
  double maxChildSize = 0.92,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? backgroundColor,
}) {
  HapticFeedback.mediumImpact();

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    builder: (context) => LiquidGlassSheetContent(
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      backgroundColor: backgroundColor,
      child: child,
    ),
  );
}

class LiquidGlassSheetContent extends StatelessWidget {
  final Widget child;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final Color? backgroundColor;

  const LiquidGlassSheetContent({
    super.key,
    required this.child,
    required this.initialChildSize,
    required this.minChildSize,
    required this.maxChildSize,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusLiquidGlassSheet),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: AppDimensions.blurSigmaLiquidGlass,
              sigmaY: AppDimensions.blurSigmaLiquidGlass,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor ??
                    (isDark
                        ? AppColors.liquidGlassBackgroundDark
                        : AppColors.liquidGlassBackgroundLight),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(
                    AppDimensions.radiusLiquidGlassSheet,
                  ),
                ),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? AppColors.liquidGlassBorderDark
                        : AppColors.liquidGlassBorderLight,
                    width: 0.5,
                  ),
                ),
              ),
              child: Stack(
                children: [
                  // Specular highlight
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 80,
                    child: IgnorePointer(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.liquidGlassSpecularLight,
                              Colors.transparent,
                            ],
                          ),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(
                              AppDimensions.radiusLiquidGlassSheet,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Content
                  Column(
                    children: [
                      // Drag handle
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        width: 36,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                      // Child content
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          child: child,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).animate().fadeIn(duration: 300.ms, curve: Curves.easeOutCubic).slideY(
          begin: 0.1,
          end: 0,
          duration: 350.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
