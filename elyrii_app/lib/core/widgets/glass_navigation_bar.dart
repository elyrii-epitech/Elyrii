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
    return Container(
      margin: margin,
      height: height,
      child: ElyriiGlassSurface(
        role: GlassRole.navigation,
        borderRadius: BorderRadius.circular(borderRadius),
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

/// Élément interactif de navigation avec rebond élastique et flash blanc
/// spéculaire (effet Apple Liquid Glass).
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

class _GlassNavItemViewState extends State<_GlassNavItemView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flashController;
  late final Animation<double> _flashAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _flashAnimation = CurvedAnimation(
      parent: _flashController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
    ElyriiHaptics.selection();
  }

  void _handleTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
    _flashController.forward(from: 0);
    widget.onItemSelected(widget.item.index);
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = AppColors.primary;

    return Expanded(
      child: Semantics(
        button: true,
        selected: widget.isSelected,
        label:
            'Onglet ${widget.item.label}, ${widget.item.index + 1} sur ${widget.totalItems}',
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          behavior: HitTestBehavior.opaque,
          child: AnimatedScale(
            // Rebond élastique Apple Liquid Glass (compression 0.88 puis ressort)
            scale: _isPressed ? 0.88 : 1.0,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutBack,
            child: AnimatedBuilder(
              animation: widget.iconController,
              builder: (context, child) {
                final easedValue = Curves.easeOutCubic.transform(
                  widget.iconController.value,
                );
                final scale = 1.0 + (easedValue * 0.08);

                return AnimatedContainer(
                  duration: const Duration(
                    milliseconds: AppDimensions.animationDurationLiquidGlass,
                  ),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? (widget.isDark
                              ? Colors.white.withValues(alpha: 0.14)
                              : Colors.black.withValues(alpha: 0.08))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
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
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
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
                            child: Text(
                              widget.item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      // Flash blanc spéculaire au clic (effet liquid glass Apple)
                      AnimatedBuilder(
                        animation: _flashAnimation,
                        builder: (context, _) {
                          if (_flashAnimation.value <= 0 ||
                              _flashAnimation.value >= 1) {
                            return const SizedBox();
                          }
                          return Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                color: Colors.white.withValues(
                                  alpha: (0.35 * (1.0 - _flashAnimation.value))
                                      .clamp(0.0, 1.0),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
