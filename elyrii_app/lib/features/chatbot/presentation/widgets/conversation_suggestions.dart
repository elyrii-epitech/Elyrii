import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';

class ConversationSuggestions extends StatelessWidget {
  final ValueChanged<String> onSuggestionTap;
  const ConversationSuggestions({super.key, required this.onSuggestionTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppDimensions.spacing8,
      runSpacing: AppDimensions.spacing8,
      children: [
        for (final suggestion in const [
          (
            label: 'Ma journée',
            message: 'J’aimerais parler de ma journée',
            icon: Icons.wb_sunny_outlined,
          ),
          (
            label: 'Retrouver mon calme',
            message: 'Aide-moi à retrouver mon calme',
            icon: Icons.air_rounded,
          ),
        ])
          OutlinedButton.icon(
            onPressed: () => onSuggestionTap(suggestion.message),
            icon: Icon(suggestion.icon, size: 17),
            label: Text(suggestion.label),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.textSecondary,
              side: BorderSide(
                color: isDark
                    ? const Color(0xFF373739)
                    : const Color(0xFFE2E2E6),
              ),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacing16,
                vertical: AppDimensions.spacing12,
              ),
              minimumSize: const Size(0, 44),
              textStyle: AppTextStyles.labelMedium(),
            ),
          ),
      ],
    );
  }
}
