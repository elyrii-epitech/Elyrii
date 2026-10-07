import '../../../../core/accessibility/motion.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/material.dart';

class DashboardSkeleton extends StatelessWidget {
  final bool isDark;

  const DashboardSkeleton({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);
    Widget block(double height) {
      final box = Container(
        height: height,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
        ),
      );
      return box
          .animateRespectingMotion(
            context,
            onPlay: (controller) => controller.repeat(),
          )
          .shimmer(
            duration: 1400.ms,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.5),
          );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: block(92)),
            const SizedBox(width: 12),
            Expanded(child: block(92)),
          ],
        ),
        const SizedBox(height: 12),
        block(72),
      ],
    );
  }
}
