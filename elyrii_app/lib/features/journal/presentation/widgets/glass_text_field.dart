import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/glass/elyrii_glass_surface.dart';

class GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isDark;
  final int? maxLines;
  final int? minLines;
  final double fontSize;
  final FontWeight fontWeight;

  const GlassTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.isDark,
    this.maxLines,
    this.minLines,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w400,
  });

  @override
  Widget build(BuildContext context) {
    return ElyriiGlassSurface(
      role: GlassRole.floatingControl,
      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        minLines: minLines,
        style: TextStyle(
          color: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: 1.5,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
            fontSize: fontSize,
            fontWeight: FontWeight.w300,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(AppDimensions.paddingMd),
        ),
      ),
    );
  }
}
