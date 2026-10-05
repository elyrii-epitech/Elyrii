import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Allocates the actual header height instead of overlaying a fixed spacer.
class ElyriiPageFrame extends StatelessWidget {
  const ElyriiPageFrame({super.key, required this.header, required this.child});

  final Widget header;
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: header,
        ),
        Expanded(child: child),
      ],
    ),
  );
}

/// Compact page titles remain at the top, beside their buttons.
class ElyriiPageHeader extends StatelessWidget {
  const ElyriiPageHeader({
    super.key,
    required this.title,
    required this.leading,
    this.subtitle,
    this.trailing = const SizedBox(width: 44),
  });

  final String title;
  final String? subtitle;
  final Widget leading;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        leading,
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: [
              // Only the title scales down if a long name runs out of room.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  maxLines: 1,
                  style: AppTextStyles.titleLarge(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        trailing,
      ],
    );
  }
}
