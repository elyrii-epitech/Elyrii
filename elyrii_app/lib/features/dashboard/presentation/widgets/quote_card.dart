import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';

/// Widget affichant la citation du jour avec effet glassmorphism subtil
class QuoteCard extends StatelessWidget {
  final String quote;
  final bool isDark;

  const QuoteCard({super.key, required this.quote, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingLg,
        vertical: AppDimensions.paddingMd,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF201E24) : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          // Icône citation
          Icon(
            Icons.format_quote_rounded,
            size: 20,
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          // Texte de la citation
          Expanded(
            child: Text(
              '"$quote"',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
