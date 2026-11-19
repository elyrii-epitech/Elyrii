import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

class GlassBarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  const GlassBarButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(AppDimensions.controlSize),
        backgroundColor: dark
            ? AppColors.glassBackgroundDark
            : AppColors.glassBackgroundLight,
        side: BorderSide(
          color: dark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
          width: .5,
        ),
      ),
      icon: Icon(icon, color: context.textPrimary),
    );
  }
}
