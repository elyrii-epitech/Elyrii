import 'package:flutter/material.dart';

import '../../../../core/config/mascot_themes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';
import '../../data/models/mascot_appearance.dart';
import '../../data/models/mascot_model.dart';

class MascotStyleEditor extends StatelessWidget {
  const MascotStyleEditor({
    super.key,
    required this.mascot,
    required this.onChanged,
  });
  final MascotModel mascot;
  final ValueChanged<MascotModel> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final secondary = dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Les Esprits d’Elyrii',
          style: AppTextStyles.titleMedium(
            color: primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Choisis une ambiance, puis compose ton propre look.',
          style: AppTextStyles.bodySmall(color: secondary),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 280
                ? 1
                : constraints.maxWidth < 330 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.3
                ? 2
                : 3;
            final width =
                (constraints.maxWidth -
                    (columns - 1) * AppDimensions.spacingSm) /
                columns;
            return Wrap(
              spacing: AppDimensions.spacingSm,
              runSpacing: AppDimensions.spacingSm,
              children: [
                for (final theme in MascotThemes.all)
                  SizedBox(
                    width: width,
                    child: _StyleTile(
                      label: theme.name,
                      selected:
                          mascot.themeId == theme.id &&
                          mascot.appearance.colors.isEmpty,
                      onTap: () => onChanged(
                        mascot.copyWith(
                          themeId: theme.id,
                          appearance: MascotAppearance(
                            finish: mascot.appearance.finish,
                          ),
                        ),
                      ),
                      child: SizedBox(
                        height: 48,
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (final color in theme.paletteColors)
                                Container(
                                  width: 24,
                                  height: 24,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: dark
                                          ? Colors.white24
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        Text(
          'La touche finale',
          style: AppTextStyles.titleSmall(
            color: primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Une matière, trois façons de révéler ses couleurs.',
          style: AppTextStyles.bodySmall(color: secondary),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final finish in MascotFinish.values)
              ChoiceChip(
                label: Text(switch (finish) {
                  MascotFinish.velours => 'Velours',
                  MascotFinish.satin => 'Satin',
                  MascotFinish.porcelain => 'Porcelaine',
                }),
                selected: mascot.appearance.finish == finish,
                onSelected: (_) => onChanged(
                  mascot.copyWith(
                    appearance: mascot.appearance.withFinish(finish),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StyleTile extends StatelessWidget {
  const _StyleTile({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      selected: selected,
      child: LiquidGlassCard(
        padding: EdgeInsets.zero,
        borderColor: selected
            ? (dark ? AppColors.primaryDark : AppColors.primary).withValues(
                alpha: 0.55,
              )
            : null,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                children: [
                  child,
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 32),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelMedium(
                        color: dark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 15,
                    color: selected
                        ? (dark ? AppColors.primaryDark : AppColors.primary)
                        : Colors.transparent,
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
