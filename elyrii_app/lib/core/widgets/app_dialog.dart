import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';
import '../design_system/haptics/elyrii_haptics.dart';

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required Widget child,
  bool barrierDismissible = true,
  String? title,
  List<AppDialogAction>? actions,
}) {
  ElyriiHaptics.medium();

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    requestFocus: true,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return AppDialogContent(title: title, actions: actions, child: child);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curvedAnimation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}

class AppDialogAction {
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;
  final bool isDefault;

  const AppDialogAction({
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
    this.isDefault = false,
  });
}

class AppDialogContent extends StatelessWidget {
  final String? title;
  final Widget child;
  final List<AppDialogAction>? actions;

  const AppDialogContent({
    super.key,
    this.title,
    required this.child,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacing32,
              ),
              constraints: const BoxConstraints(maxWidth: 320),
              child: Material(
                color: AppColors.sheetSurface(isDark),
                borderRadius: BorderRadius.circular(AppDimensions.radius20),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.spacing20,
                        AppDimensions.spacing20,
                        AppDimensions.spacing20,
                        AppDimensions.spacing16,
                      ),
                      child: Column(
                        children: [
                          if (title != null) ...[
                            Semantics(
                              header: true,
                              namesRoute: true,
                              child: Text(
                                title!,
                                style: AppTextStyles.titleMedium(
                                  color: context.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spacing8),
                          ],
                          DefaultTextStyle(
                            style: AppTextStyles.bodyMedium(
                              color: context.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                            child: child,
                          ),
                        ],
                      ),
                    ),
                    if (actions != null && actions!.isNotEmpty) ...[
                      Divider(
                        height: 0.5,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.1),
                      ),
                      _buildActions(context, isDark),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, bool isDark) {
    if (actions!.length == 2 &&
        MediaQuery.textScalerOf(context).scale(14) < 21 &&
        MediaQuery.sizeOf(context).width >= 360) {
      return IntrinsicHeight(
        child: Row(
          children: [
            Expanded(child: _buildActionButton(context, actions![0], isDark)),
            VerticalDivider(
              width: 0.5,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.1),
            ),
            Expanded(child: _buildActionButton(context, actions![1], isDark)),
          ],
        ),
      );
    }

    return Column(
      children: actions!.asMap().entries.map((entry) {
        final index = entry.key;
        final action = entry.value;
        return Column(
          children: [
            if (index > 0)
              Divider(
                height: 0.5,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.1),
              ),
            _buildActionButton(context, action, isDark),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    AppDialogAction action,
    bool isDark,
  ) {
    final textColor = action.isDestructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        foregroundColor: action.isDestructive
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing16,
          vertical: AppDimensions.spacing12,
        ),
      ),
      onPressed: () {
        ElyriiHaptics.light();
        action.onPressed();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacing12),
        child: Text(
          action.label,
          style: action.isDefault
              ? AppTextStyles.labelLarge(color: textColor)
              : AppTextStyles.dialogAction(color: textColor),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
