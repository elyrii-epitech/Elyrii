import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../data/models/coach_model.dart';

/// Cellule d'activité dans le conteneur groupé iOS : icône squircle colorée,
/// titre et description, pilule de durée arrondie et glyphe de droite qui
/// distingue ce que fait le tap — lecture guidée (chevron) ou lancement
/// immédiat d'une expérience native (lecture).
class CoachActivityCell extends StatefulWidget {
  final CoachActivity activity;
  final bool isDark;
  final VoidCallback onTap;

  const CoachActivityCell({
    super.key,
    required this.activity,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<CoachActivityCell> createState() => _CoachActivityCellState();
}

class _CoachActivityCellState extends State<CoachActivityCell> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.activity.category.color;
    final launchesExperience = widget.activity.kind != CoachActivityKind.guidance;

    return Semantics(
      label: widget.activity.title,
      hint:
          'Lance ${widget.activity.durationMinutes} minutes — ${widget.activity.category.label}',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        // Surbrillance discrète à l'appui, façon cellule iOS groupée.
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          color: _isPressed
              ? (widget.isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04))
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(widget.activity.icon, size: 20, color: color),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.activity.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.activity.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Badge de durée en pilule arrondie, à gauche du glyphe.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusCircular,
                  ),
                ),
                child: Text(
                  '${widget.activity.durationMinutes} min',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                launchesExperience
                    ? Icons.play_arrow_rounded
                    : Icons.chevron_right_rounded,
                size: launchesExperience ? 22 : 18,
                color: launchesExperience
                    ? color
                    : (widget.isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
