// iOS 26 Liquid Glass Card
// Part of the Liquid Glass Widget Kit

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/glass_performance_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';

class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double borderRadius;
  final Color? color;
  final Color? borderColor;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.borderRadius = 20,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final performanceService = GlassPerformanceService();
    final blurSigma = performanceService.getEffectiveBlurSigma(
      AppDimensions.blurSigmaRegular,
    );

    final container = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ??
            (isDark
                ? AppColors.liquidGlassBackgroundDark
                : AppColors.liquidGlassBackgroundLight),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ??
              (isDark
                  ? AppColors.liquidGlassBorderDark
                  : AppColors.liquidGlassBorderLight),
          width: 0.5,
        ),
      ),
      child: child,
    );

    final Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: blurSigma > 0
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: container,
            )
          : container,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap?.call();
        },
        child: content,
      );
    }

    return content;
  }
}
