import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../data/models/coach_model.dart';

/// Rangée de filtres « besoin immédiat » : l'utilisateur dit au coach ce
/// dont il a besoin, le coach répond avec les activités adaptées.
///
/// Chip sélectionnable au tap (tap à nouveau pour revenir à la sélection par
/// défaut), avec haptique de sélection et retournement visuel doux —
/// façon segmented control iOS, sans en copier le look rigide.
class NeedSelector extends StatelessWidget {
  final List<CoachNeed> needs;
  final CoachNeed? selected;
  final ValueChanged<CoachNeed?> onSelect;

  const NeedSelector({
    super.key,
    required this.needs,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: needs.length,
        itemBuilder: (context, index) {
          final need = needs[index];
          return _NeedChip(
            need: need,
            isDark: isDark,
            isSelected: selected == need,
            onTap: () {
              ElyriiHaptics.selection();
              onSelect(selected == need ? null : need);
            },
          );
        },
      ),
    );
  }
}

class _NeedChip extends StatefulWidget {
  final CoachNeed need;
  final bool isDark;
  final bool isSelected;
  final VoidCallback onTap;

  const _NeedChip({
    required this.need,
    required this.isDark,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NeedChip> createState() => _NeedChipState();
}

class _NeedChipState extends State<_NeedChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.need.color;

    return Semantics(
      label: widget.need.label,
      button: true,
      selected: widget.isSelected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? color.withValues(alpha: 0.16)
                  : (widget.isDark
                        ? AppColors.cardDark
                        : AppColors.cardLight),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                width: 1,
                color: widget.isSelected
                    ? color.withValues(alpha: 0.45)
                    : (widget.isDark
                          ? AppColors.dividerDark
                          : AppColors.dividerLight),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.need.icon,
                  size: 16,
                  color: widget.isSelected
                      ? color
                      : (widget.isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
                ),
                const SizedBox(width: 7),
                Text(
                  widget.need.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                    color: widget.isSelected
                        ? color
                        : (widget.isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
