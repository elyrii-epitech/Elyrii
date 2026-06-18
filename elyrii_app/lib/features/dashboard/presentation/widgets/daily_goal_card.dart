import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../providers/dashboard_provider.dart';

/// Widget affichant l'objectif du jour avec progression
class DailyGoalCard extends StatefulWidget {
  final GoalType goal;
  final bool isCompleted;
  final bool isDark;
  final VoidCallback? onComplete;

  const DailyGoalCard({
    super.key,
    required this.goal,
    required this.isCompleted,
    this.isDark = false,
    this.onComplete,
  });

  @override
  State<DailyGoalCard> createState() => _DailyGoalCardState();
}

class _DailyGoalCardState extends State<DailyGoalCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkController;
  late Animation<double> _checkScale;
  late Animation<double> _checkOpacity;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.elasticOut),
    );

    _checkOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    if (widget.isCompleted) {
      _checkController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(DailyGoalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCompleted && !oldWidget.isCompleted) {
      _checkController.forward();
    }
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (!widget.isCompleted) {
          setState(() => _isPressed = true);
          HapticFeedback.lightImpact();
        }
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        if (!widget.isCompleted) {
          widget.onComplete?.call();
        }
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.paddingMd),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.isCompleted
                        ? [
                            AppColors.success.withValues(alpha: 0.2),
                            AppColors.success.withValues(alpha: 0.1),
                          ]
                        : widget.isDark
                        ? [
                            Colors.white.withValues(alpha: 0.1),
                            Colors.white.withValues(alpha: 0.05),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.85),
                            Colors.white.withValues(alpha: 0.6),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                  border: Border.all(
                    color: widget.isCompleted
                        ? AppColors.success.withValues(alpha: 0.4)
                        : widget.isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.isCompleted
                          ? AppColors.success.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Icône/Checkbox
                    _buildCheckbox(),
                    const SizedBox(width: AppDimensions.spacingMd),
                    // Contenu
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Objectif du jour',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: widget.isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.isCompleted
                                ? widget.goal.completedMessage
                                : widget.goal.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: widget.isCompleted
                                  ? AppColors.success
                                  : widget.isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                              decoration: widget.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Indicateur de tap
                    if (!widget.isCompleted)
                      Icon(
                        Icons.touch_app_rounded,
                        size: 20,
                        color: widget.isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
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

  Widget _buildCheckbox() {
    return AnimatedBuilder(
      animation: _checkController,
      builder: (context, child) {
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: widget.isCompleted
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.success.withValues(alpha: 0.8),
                      AppColors.success.withValues(alpha: 0.6),
                    ],
                  )
                : null,
            color: widget.isCompleted
                ? null
                : widget.isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.8),
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isCompleted
                  ? AppColors.success
                  : widget.isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : AppColors.primary.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: widget.isCompleted
                ? [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: widget.isCompleted
                ? Transform.scale(
                    scale: _checkScale.value,
                    child: Opacity(
                      opacity: _checkOpacity.value,
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  )
                : Icon(widget.goal.icon, size: 20, color: AppColors.primary),
          ),
        );
      },
    );
  }
}
