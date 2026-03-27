import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../providers/dashboard_provider.dart';

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
                    HapticFeedback.mediumImpact();
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.isSelected
                      ? [
                          AppColors.primary.withValues(alpha: 0.8),
                          AppColors.primaryDark.withValues(alpha: 0.6),
                        ]
                      : widget.isDark
                          ? [
                              Colors.white.withValues(alpha: 0.12),
                              Colors.white.withValues(alpha: 0.06),
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.8),
                              Colors.white.withValues(alpha: 0.5),
                            ],
                ),
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                border: Border.all(
                  color: widget.isSelected
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : widget.isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.6),
                  width: widget.isSelected ? 2 : 1,
                ),
                boxShadow: widget.isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Center(
                child: Text(
                  widget.mood.emoji,
                  style: TextStyle(fontSize: widget.isSelected ? 28 : 24),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
