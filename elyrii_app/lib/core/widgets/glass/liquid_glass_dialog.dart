// iOS 26 Liquid Glass Dialog
// Part of the Liquid Glass Widget Kit

import 'package:flutter/material.dart';
import '../../glass/elyrii_glass_surface.dart';
import '../../../core/design_system/haptics/elyrii_haptics.dart';

/// Shows an iOS 26 style dialog with liquid glass effect
Future<T?> showLiquidGlassDialog<T>({
  required BuildContext context,
  required Widget child,
  bool barrierDismissible = true,
  String? title,
  List<LiquidGlassDialogAction>? actions,
}) {
  ElyriiHaptics.medium();

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.4),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return LiquidGlassDialogContent(
        title: title,
        actions: actions,
        child: child,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curvedAnimation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}

class LiquidGlassDialogAction {
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;
  final bool isDefault;

  const LiquidGlassDialogAction({
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
    this.isDefault = false,
  });
}

class LiquidGlassDialogContent extends StatelessWidget {
  final String? title;
  final Widget child;
  final List<LiquidGlassDialogAction>? actions;

  const LiquidGlassDialogContent({
    super.key,
    this.title,
    required this.child,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        constraints: const BoxConstraints(maxWidth: 320),
        child: ElyriiGlassSurface(
          role: GlassRole.dialog,
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    children: [
                      if (title != null) ...[
                        Text(
                          title!,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                      ],
                      DefaultTextStyle(
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.7)
                              : Colors.black.withValues(alpha: 0.6),
                        ),
                        textAlign: TextAlign.center,
                        child: child,
                      ),
                    ],
                  ),
                ),
                if (actions != null && actions!.isNotEmpty) ...[
                  Divider(
                    height: 0.5,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.1),
                  ),
                  _buildActions(context, isDark),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, bool isDark) {
    if (actions!.length == 2) {
      return IntrinsicHeight(
        child: Row(
          children: [
            Expanded(child: _buildActionButton(context, actions![0], isDark)),
            VerticalDivider(
              width: 0.5,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.1),
            ),
            Expanded(child: _buildActionButton(context, actions![1], isDark)),
          ],
        ),
      );
    }

    return Column(
      children: actions!.asMap().entries.map((entry) {
        final index = entry.key;
        final action = entry.value;
        return Column(
          children: [
            if (index > 0)
              Divider(
                height: 0.5,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.1),
              ),
            _buildActionButton(context, action, isDark),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    LiquidGlassDialogAction action,
    bool isDark,
  ) {
    Color textColor;
    if (action.isDestructive) {
      textColor = Colors.red;
    } else if (action.isDefault) {
      textColor = Theme.of(context).primaryColor;
    } else {
      textColor = Theme.of(context).primaryColor;
    }

    return InkWell(
      onTap: () {
        ElyriiHaptics.light();
        action.onPressed();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          action.label,
          style: TextStyle(
            fontSize: 17,
            fontWeight: action.isDefault ? FontWeight.w600 : FontWeight.w400,
            color: textColor,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
