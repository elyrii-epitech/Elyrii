import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/glass/elyrii_glass_surface.dart';

class GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isDark;
  final int? maxLines;
  final int? minLines;
  final TextStyle? style;

  const GlassTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.isDark,
    this.maxLines,
    this.minLines,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? AppTextStyles.bodyLarge();
    return ElyriiGlassSurface(
      role: GlassRole.floatingControl,
      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        minLines: minLines,
        style: baseStyle.copyWith(
          color: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
        ),
        decoration: InputDecoration(
          labelText: hint,
          hintText: hint,
          hintStyle: baseStyle.copyWith(
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
            fontWeight: FontWeight.w300,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(AppDimensions.paddingMd),
        ),
      ),
    );
  }
}
