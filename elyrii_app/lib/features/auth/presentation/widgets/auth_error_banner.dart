import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';

/// Bannière d'alerte contextuelle affichée en haut de formulaire d'auth.
///
/// Remplace les SnackBars Android : message inline discret, teinté selon la
/// sévérité, avec icône et libellé système.
class AuthErrorBanner extends StatelessWidget {
  final String message;
  final bool isSuccess;

  const AuthErrorBanner({
    super.key,
    required this.message,
    this.isSuccess = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = isSuccess ? AppColors.success : AppColors.warning;

    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing16,
          vertical: AppDimensions.spacing12,
        ),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: isDark ? 0.14 : 0.10),
          borderRadius: BorderRadius.circular(AppDimensions.radius12),
          border: Border.all(color: tint.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(
              isSuccess
                  ? Icons.check_circle_outline_rounded
                  : Icons.info_outline_rounded,
              size: 20,
              color: tint,
            ),
            const SizedBox(width: AppDimensions.spacing8),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyMedium(color: context.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
