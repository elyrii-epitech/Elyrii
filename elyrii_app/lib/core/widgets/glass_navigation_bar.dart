import 'package:flutter/material.dart';

import '../design_system/haptics/elyrii_haptics.dart';
import '../glass/elyrii_glass_surface.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_motion.dart';
import '../theme/app_text_styles.dart';

class GlassNavItem {
  final IconData icon;
  final String label;
  final int index;

  const GlassNavItem({
    required this.icon,
    required this.label,
    required this.index,
  });
}

class GlassNavigationBar extends StatelessWidget {
  final List<GlassNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onItemSelected;
  final bool isDark;

  const GlassNavigationBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onItemSelected,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) => ElyriiGlassSurface(
    role: GlassRole.navigation,
    lifted: true,
    borderRadius: BorderRadius.circular(AppDimensions.dockHeight / 2),
    height: AppDimensions.dockHeight,
    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing4),
    child: Row(
      children: [
        for (final item in items)
          Expanded(
            child: _GlassNavItemView(
              item: item,
              isSelected: currentIndex == item.index,
              isDark: isDark,
              totalItems: items.length,
              onItemSelected: onItemSelected,
            ),
          ),
      ],
    ),
  );
}

class _GlassNavItemView extends StatefulWidget {
  final GlassNavItem item;
  final bool isSelected;
  final bool isDark;
  final int totalItems;
  final ValueChanged<int> onItemSelected;

  const _GlassNavItemView({
    required this.item,
    required this.isSelected,
    required this.isDark,
    required this.totalItems,
    required this.onItemSelected,
  });

  @override
  State<_GlassNavItemView> createState() => _GlassNavItemViewState();
}

class _GlassNavItemViewState extends State<_GlassNavItemView> {
  bool _isPressed = false;
  bool _showFocus = false;

  void _activate() {
    ElyriiHaptics.selection();
    widget.onItemSelected(widget.item.index);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final tint = widget.isDark ? AppColors.primaryDark : AppColors.primary;
    final label = context.textPrimary;
    final color = widget.isSelected ? tint : label;

    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      selected: widget.isSelected,
      onTap: _activate,
      label:
          'Onglet ${widget.item.label}, ${widget.item.index + 1} sur ${widget.totalItems}',
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (value) => setState(() => _showFocus = value),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        child: GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onTap: _activate,
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedScale(
            scale: _isPressed && !media.disableAnimations ? 0.96 : 1,
            duration: media.disableAnimations
                ? Duration.zero
                : AppMotion.dockPress,
            curve: AppMotion.dockPressCurve,
            child: Center(
              child: Container(
                width: AppDimensions.dockItemWidth,
                constraints: const BoxConstraints(
                  minHeight: AppDimensions.dockItemHeight,
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimensions.dockItemPadding,
                ),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? AppColors.dockSelection(widget.isDark)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppDimensions.radius26),
                  border:
                      _showFocus || (media.highContrast && widget.isSelected)
                      ? Border.all(
                          color: _showFocus ? tint : label,
                          width: AppDimensions.borderWidthThin,
                        )
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.item.icon,
                      fill: widget.isSelected ? 1 : 0,
                      size: AppDimensions.dockIcon,
                      color: color,
                    ),
                    const SizedBox(height: AppDimensions.dockItemGap),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.item.label,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.dockLabel(color: color),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
