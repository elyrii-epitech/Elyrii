// iOS 26 Liquid Glass Sheet
// Part of the Liquid Glass Widget Kit

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../glass/elyrii_glass_surface.dart';
import '../../theme/app_dimensions.dart';
import '../../../core/design_system/haptics/elyrii_haptics.dart';

/// Shows an iOS 26 style bottom sheet with liquid glass effect
Future<T?> showLiquidGlassSheet<T>({
  required BuildContext context,
  Widget? child,
  Widget Function(BuildContext, ScrollController)? scrollableBuilder,
  double initialChildSize = 0.5,
  double minChildSize = 0.25,
  double maxChildSize = 0.92,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
  EdgeInsetsGeometry contentPadding = const EdgeInsets.all(20),
  Color? backgroundColor,
}) {
  assert((child == null) != (scrollableBuilder == null));
  ElyriiHaptics.medium();

  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
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
      contentPadding: contentPadding,
      scrollableBuilder: scrollableBuilder,
      child: child,
    ),
  );
}

class LiquidGlassSheetContent extends StatelessWidget {
  final Widget? child;
  final Widget Function(BuildContext, ScrollController)? scrollableBuilder;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final Color? backgroundColor;
  final EdgeInsetsGeometry contentPadding;

  const LiquidGlassSheetContent({
    super.key,
    this.child,
    this.scrollableBuilder,
    required this.initialChildSize,
    required this.minChildSize,
    required this.maxChildSize,
    this.backgroundColor,
    this.contentPadding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
          initialChildSize: initialChildSize,
          minChildSize: minChildSize,
          maxChildSize: maxChildSize,
          builder: (context, scrollController) {
            return ElyriiGlassSurface(
              role: GlassRole.modalSheet,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppDimensions.radiusLiquidGlassSheet),
              ),
              glassColor: backgroundColor,
              child: Stack(
                children: [
                  Column(
                    children: [
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
                      Expanded(
                        child:
                            scrollableBuilder?.call(
                              context,
                              scrollController,
                            ) ??
                            SingleChildScrollView(
                              controller: scrollController,
                              padding: contentPadding,
                              child: child,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        )
        .animate()
        .fadeIn(duration: 300.ms, curve: Curves.easeOutCubic)
        .slideY(
          begin: 0.1,
          end: 0,
          duration: 350.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
