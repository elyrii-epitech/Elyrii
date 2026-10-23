import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_sheet_route.dart';
import '../../../../core/widgets/accessible_action.dart';
import '../../../../core/constants/profile_option_labels.dart';

const wellnessGoals = [
  'Gerer mon stress',
  'Ameliorer mon sommeil',
  'Cultiver ma mindfulness',
  'Developper ma confiance',
  'Prendre soin de moi',
  'Retrouver du calme',
];

class ProfileCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final double radius;
  const ProfileCard({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(AppDimensions.spacing16),
    this.radius = AppDimensions.radius20,
  });
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color ?? (dark ? AppColors.surfaceDark : AppColors.surfaceLight),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          width: AppDimensions.profileHairline,
          color: dark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: child,
    );
  }
}

class ProfileGroup extends StatelessWidget {
  final List<Widget> children;
  const ProfileGroup({super.key, required this.children});
  @override
  Widget build(BuildContext context) => ProfileCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i != 0)
            Divider(
              height: AppDimensions.profileHairline,
              thickness: AppDimensions.profileHairline,
              indent: AppDimensions.profileRowHeight,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.dividerDark
                  : AppColors.dividerLight,
            ),
          children[i],
        ],
      ],
    ),
  );
}

class ProfileRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  const ProfileRow({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    this.value,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppDimensions.profileRowHeight,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing16,
          vertical: AppDimensions.spacing8,
        ),
        child: Row(
          children: [
            Container(
              width: AppDimensions.profileSquare,
              height: AppDimensions.profileSquare,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(
                  AppDimensions.profileSquareRadius,
                ),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: AppDimensions.profileIcon,
              ),
            ),
            const SizedBox(width: AppDimensions.spacing12),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.titleSmall(
                  color: destructive
                      ? AppColors.profileDanger(dark)
                      : context.textPrimary,
                ),
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: AppDimensions.spacing8),
              Expanded(
                child: Text(
                  value!,
                  textAlign: TextAlign.right,
                  style: AppTextStyles.bodySmall(color: context.textSecondary),
                ),
              ),
            ],
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                size: AppDimensions.iconSm,
                color: context.textTertiary,
              ),
          ],
        ),
      ),
    );
    return onTap == null
        ? row
        : AccessibleAction(label: title, onPressed: onTap!, child: row);
  }
}

class ProfileSection extends StatelessWidget {
  final String title;
  final Widget child;
  final String? footer;
  const ProfileSection({
    super.key,
    required this.title,
    required this.child,
    this.footer,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppDimensions.spacing20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing16,
            vertical: AppDimensions.spacing8,
          ),
          child: Text(
            title,
            style: AppTextStyles.bodySmall(color: context.textTertiary),
          ),
        ),
        child,
        if (footer != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacing16,
              vertical: AppDimensions.spacing8,
            ),
            child: Text(
              footer!,
              style: AppTextStyles.bodySmall(color: context.textSecondary),
            ),
          ),
      ],
    ),
  );
}

class ProfileSegments<T> extends StatelessWidget {
  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onChanged;
  const ProfileSegments({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing2),
      decoration: BoxDecoration(
        color: AppColors.track(dark),
        borderRadius: BorderRadius.circular(AppDimensions.radius12),
      ),
      child: Row(
        children: [
          for (final entry in options.entries)
            Expanded(
              child: AccessibleAction(
                label: entry.value,
                selected: selected == entry.key,
                excludeChildSemantics: true,
                onPressed: () => onChanged(entry.key),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppDimensions.controlSize,
                  ),
                  child: Center(
                    child: AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : AppMotion.profileSegment,
                      curve: AppMotion.accueilEase,
                      constraints: const BoxConstraints(
                        minHeight: AppDimensions.profileSegment,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected == entry.key
                            ? AppColors.primaryText(dark)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radius8,
                        ),
                      ),
                      child: Text(
                        entry.value,
                        style: AppTextStyles.labelMedium(
                          color: selected == entry.key
                              ? AppColors.onTint(dark)
                              : context.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ProfileToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const ProfileToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.profileToggle;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: label,
      toggled: value,
      onTap: () => onChanged(!value),
      child: AccessibleAction(
        label: label,
        onPressed: () => onChanged(!value),
        child: SizedBox(
          width: AppDimensions.profileToggleWidth,
          height: AppDimensions.controlSize,
          child: Center(
            child: AnimatedContainer(
              duration: duration,
              curve: AppMotion.accueilEase,
              width: AppDimensions.profileToggleWidth,
              height: AppDimensions.profileToggleHeight,
              decoration: BoxDecoration(
                color: value
                    ? AppColors.profileToggle
                    : AppColors.track(
                        Theme.of(context).brightness == Brightness.dark,
                      ),
                borderRadius: BorderRadius.circular(AppDimensions.radius16),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: duration,
                    curve: AppMotion.accueilEase,
                    left:
                        AppDimensions.spacing2 +
                        (value ? AppDimensions.profileToggleTravel : 0),
                    top: AppDimensions.spacing2,
                    child: Container(
                      width: AppDimensions.profileToggleThumb,
                      height: AppDimensions.profileToggleThumb,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final bool danger;
  const ProfileButton({
    super.key,
    required this.label,
    this.onPressed,
    this.filled = true,
    this.danger = false,
  });
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size.fromHeight(AppDimensions.journalBigButton),
        foregroundColor: danger
            ? AppColors.profileDanger(dark)
            : filled
            ? AppColors.onTint(dark)
            : AppColors.primaryText(dark),
        backgroundColor: danger
            ? AppColors.profileDanger(dark).withValues(alpha: .12)
            : filled
            ? AppColors.primaryText(dark)
            : AppColors.tintSoft(dark),
        shape: const StadiumBorder(),
        textStyle: AppTextStyles.labelLarge(),
      ),
      child: Text(label),
    );
  }
}

Future<T?> profileSheet<T>(BuildContext context, String title, Widget child) =>
    Navigator.of(context, rootNavigator: true).push<T>(
      AppSheetRoute<T>(
        reduced: MediaQuery.disableAnimationsOf(context),
        builder: (_) => AppSheetPanel(title: title, child: child),
      ),
    );

Future<String?> chooseWellnessGoal(BuildContext context, String? current) {
  var selected = current;
  return profileSheet<String>(
    context,
    'Ce qui compte pour toi',
    StatefulBuilder(
      builder: (context, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choisis ce dont tu as besoin en ce moment.',
            style: AppTextStyles.bodyMedium(color: context.textSecondary),
          ),
          const SizedBox(height: AppDimensions.spacing16),
          Wrap(
            spacing: AppDimensions.spacing8,
            runSpacing: AppDimensions.spacing8,
            children: [
              for (final goal in wellnessGoals)
                ChoiceChip(
                  label: Text(profileOptionLabel(goal)),
                  selected: selected == goal,
                  onSelected: (_) => setState(() => selected = goal),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),
          ProfileButton(
            label: 'Enregistrer',
            onPressed: selected == null
                ? null
                : () => Navigator.pop(context, selected),
          ),
        ],
      ),
    ),
  );
}

void profileToast(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  final dark = Theme.of(context).brightness == Brightness.dark;
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: AppDimensions.spacing24,
      right: AppDimensions.spacing24,
      bottom: AppDimensions.spacing32,
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacing16,
                vertical: AppDimensions.spacing12,
              ),
              decoration: BoxDecoration(
                color: AppColors.profileToast(dark),
                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
              ),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.profileFootnote(
                    color: dark ? Colors.white : context.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  _toast?.remove();
  _timer?.cancel();
  _toast = entry;
  overlay.insert(entry);
  _timer = Timer(AppMotion.profileToast, () {
    if (_toast == entry) {
      entry.remove();
      _toast = null;
    }
  });
}

OverlayEntry? _toast;
Timer? _timer;
