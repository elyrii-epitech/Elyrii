// iOS 26 Liquid Glass Action Sheet
// Part of the Liquid Glass Widget Kit

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';

/// Shows an iOS 26 style action sheet with liquid glass effect
Future<T?> showLiquidGlassActionSheet<T>({
  required BuildContext context,
  String? title,
  String? message,
  required List<LiquidGlassActionSheetItem> actions,
  LiquidGlassActionSheetItem? cancelAction,
}) {
  HapticFeedback.mediumImpact();

  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    builder: (context) => LiquidGlassActionSheetContent(
      title: title,
      message: message,
      actions: actions,
      cancelAction: cancelAction,
    ),
  );
}

class LiquidGlassActionSheetItem {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool isDestructive;

  const LiquidGlassActionSheetItem({
    required this.label,
    this.icon,
    required this.onPressed,
    this.isDestructive = false,
  });
}

class LiquidGlassActionSheetContent extends StatelessWidget {
  final String? title;
  final String? message;
  final List<LiquidGlassActionSheetItem> actions;
  final LiquidGlassActionSheetItem? cancelAction;

  const LiquidGlassActionSheetContent({
    super.key,
    this.title,
    this.message,
    required this.actions,
    this.cancelAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 0, 8, bottomPadding + 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main action group
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: AppDimensions.blurSigmaLiquidGlass,
                  sigmaY: AppDimensions.blurSigmaLiquidGlass,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.liquidGlassBackgroundDark
                        : AppColors.liquidGlassBackgroundLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      // Header
                      if (title != null || message != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Column(
                            children: [
                              if (title != null)
                                Text(
                                  title!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.6)
                                        : Colors.black.withValues(alpha: 0.5),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              if (message != null) ...[
                                if (title != null) const SizedBox(height: 4),
                                Text(
                                  message!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.5)
                                        : Colors.black.withValues(alpha: 0.4),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      // Divider after header
                      if (title != null || message != null)
                        Divider(
                          height: 0.5,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.black.withValues(alpha: 0.1),
                        ),
                      // Actions
                      ...actions.asMap().entries.map((entry) {
                        final index = entry.key;
                        final action = entry.value;
                        return Column(
                          children: [
                            if (index > 0 || title != null || message != null)
                              if (index > 0)
                                Divider(
                                  height: 0.5,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.15)
                                      : Colors.black.withValues(alpha: 0.1),
                                ),
                            _ActionSheetButton(
                              action: action,
                              isDark: isDark,
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
            // Cancel button
            if (cancelAction != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: AppDimensions.blurSigmaLiquidGlass,
                    sigmaY: AppDimensions.blurSigmaLiquidGlass,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.liquidGlassBackgroundDark
                          : AppColors.liquidGlassBackgroundLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _ActionSheetButton(
                      action: cancelAction!,
                      isDark: isDark,
                      isBold: true,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 250.ms)
        .slideY(begin: 0.1, end: 0, duration: 300.ms, curve: Curves.easeOutCubic);
  }
}

class _ActionSheetButton extends StatelessWidget {
  final LiquidGlassActionSheetItem action;
  final bool isDark;
  final bool isBold;

  const _ActionSheetButton({
    required this.action,
    required this.isDark,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
          action.onPressed();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (action.icon != null) ...[
                Icon(
                  action.icon,
                  size: 22,
                  color: action.isDestructive
                      ? Colors.red
                      : Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                action.label,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
                  color: action.isDestructive
                      ? Colors.red
                      : Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
