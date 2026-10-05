import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../providers/dashboard_provider.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../../core/glass/elyrii_glass_surface.dart';

/// Widget de sélection d'humeur avec effet glassmorphism
class GlassMoodSelector extends StatelessWidget {
  final bool isDark;

  const GlassMoodSelector({super.key, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            Text(
              provider.getMoodMessage(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: MoodType.values.map((mood) {
                final isSelected = provider.selectedMood == mood;
                return _MoodButton(
                  mood: mood,
                  isSelected: isSelected,
                  isDark: isDark,
                  onTap: () {
                    ElyriiHaptics.medium();
                    provider.selectMood(mood);
                  },
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}

class _MoodButton extends StatefulWidget {
  final MoodType mood;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _MoodButton({
    required this.mood,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_MoodButton> createState() => _MoodButtonState();
}

class _MoodButtonState extends State<_MoodButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  }

  @override
  void didUpdateWidget(_MoodButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.forward();
    } else if (!widget.isSelected && oldWidget.isSelected) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isPressed ? 0.9 : _scaleAnimation.value,
            child: child,
          );
        },
        child: ElyriiGlassSurface(
          role: GlassRole.floatingControl,
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          width: 56,
          height: 56,
          glassColor: widget.isSelected
              ? AppColors.primary.withValues(alpha: 0.8)
              : null,
          child: Center(
            child: Icon(
              widget.mood.icon,
              size: widget.isSelected ? 28 : 24,
              color: widget.isSelected
                  ? Colors.white
                  : (widget.isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight),
            ),
          ),
        ),
      ),
    );
  }
}
