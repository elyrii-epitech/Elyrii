import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/glass_container.dart';

/// Widget affichant la citation du jour avec effet glassmorphism subtil
class QuoteCard extends StatelessWidget {
  final String quote;
  final bool isDark;

  const QuoteCard({super.key, required this.quote, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      isDark: isDark,
      borderRadius: AppDimensions.radiusMd,
      intensity: GlassIntensity.light,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingLg,
        vertical: AppDimensions.paddingMd,
      ),
      child: Row(
        children: [
          // Icône citation
          Text(
            '💭',
            style: TextStyle(
              fontSize: 20,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
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
