import 'package:flutter/material.dart';
import '../design_system/haptics/elyrii_haptics.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../glass/elyrii_glass_surface.dart';

/// Item de navigation pour la GlassNavigationBar
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

/// Barre de navigation avec effet iOS 26 Liquid Glass
/// Widget réutilisable pour créer des navbars modernes
class GlassNavigationBar extends StatelessWidget {
  final List<GlassNavItem> items;
  final int currentIndex;
  final Function(int) onItemSelected;
  final List<AnimationController> iconControllers;
  final Animation<double>? scaleAnimation;
  final bool isDark;
  final int pressedIndex;
  final EdgeInsets margin;
  final double height;
  final double borderRadius;

  const GlassNavigationBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onItemSelected,
    required this.iconControllers,
    this.scaleAnimation,
    this.isDark = false,
    this.pressedIndex = -1,
    this.margin = const EdgeInsets.only(left: 16, right: 16, bottom: 20),
    this.height = 64.0,
    this.borderRadius = AppDimensions.radiusLiquidGlassNav, // 32.0
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    return Container(
      margin: margin,
      height: height,
      child: ElyriiGlassSurface(
        role: GlassRole.navigation,
        borderRadius: BorderRadius.circular(borderRadius),
        // Let the page tint the glass; do not lay a white sheet over it.
        // Leaving this unset preserves the opaque accessibility fallback.
        glassColor: media.highContrast
            ? null
            : theme.colorScheme.surface.withValues(alpha: isDark ? 0.20 : 0.16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: items.map((item) {
            return _GlassNavItemView(
              item: item,
              isSelected: currentIndex == item.index,
              isDark: isDark,
              totalItems: items.length,
              onItemSelected: onItemSelected,
              iconController: iconControllers[item.index],
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Une seule surface de verre, avec un repère de sélection discret.
class _GlassNavItemView extends StatefulWidget {
  final GlassNavItem item;
  final bool isSelected;
  final bool isDark;
  final int totalItems;
  final ValueChanged<int> onItemSelected;
  final AnimationController iconController;

  const _GlassNavItemView({
    required this.item,
    required this.isSelected,
    required this.isDark,
    required this.totalItems,
    required this.onItemSelected,
    required this.iconController,
  });

  @override
  State<_GlassNavItemView> createState() => _GlassNavItemViewState();
}

class _GlassNavItemViewState extends State<_GlassNavItemView> {
  bool _isPressed = false;
  bool _showFocus = false;

  void _handleTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
  }

  void _activate() {
    ElyriiHaptics.selection();
    widget.onItemSelected(widget.item.index);
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations;
    final scheme = Theme.of(context).colorScheme;
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);
    final primaryColor = widget.isDark
        ? AppColors.primaryDark
        : AppColors.primary;

    return Expanded(
      child: Semantics(
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
            onTap: _activate,
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            behavior: HitTestBehavior.opaque,
            child: AnimatedScale(
              scale: _isPressed && !reduceMotion ? 0.96 : 1.0,
              duration: duration,
              curve: Curves.easeOutCubic,
              child: AnimatedBuilder(
                animation: widget.iconController,
                builder: (context, child) {
                  final easedValue = reduceMotion
                      ? 0.0
                      : Curves.easeOutCubic.transform(
                          widget.iconController.value,
                        );
                  final scale = 1.0 + (easedValue * 0.08);

                  return AnimatedContainer(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? scheme.onSurface.withValues(
                              alpha: widget.isDark ? 0.065 : 0.055,
                            )
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: _showFocus
                            ? primaryColor
                            : (media.highContrast && widget.isSelected
                                  ? scheme.onSurface
                                  : Colors.transparent),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Translation et scale de l'icône
                        Transform.translate(
                          offset: Offset(0, -2 * easedValue),
                          child: Transform.scale(
                            scale: widget.isSelected ? scale : 1.0,
                            child: Icon(
                              widget.item.icon,
                              color: widget.isSelected
                                  ? primaryColor
                                  : (widget.isDark
                                        ? AppColors.iconDefaultDark
                                        : AppColors.iconDefaultLight),
                              size: 23,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        AnimatedDefaultTextStyle(
                          duration: duration,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: widget.isSelected ? 10.5 : 10.0,
                            fontWeight: widget.isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: widget.isSelected
                                ? primaryColor
                                : (widget.isDark
                                      ? AppColors.iconDefaultDark
                                      : AppColors.iconDefaultLight),
                            letterSpacing: -0.2,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(widget.item.label, maxLines: 1),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
