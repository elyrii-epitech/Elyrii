import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/coach_model.dart';

/// Cellule d'activité dans le conteneur groupé iOS : icône squircle colorée,
/// titre et description, pilule de durée arrondie et glyphe de droite qui
/// distingue ce que fait le tap — lecture guidée (chevron) ou lancement
/// immédiat d'une expérience native (lecture).
class CoachActivityCell extends StatefulWidget {
  /// Taille de la boîte d'icône d'une cellule, partagée avec le conteneur
  /// groupé pour aligner ses séparateurs.
  static const double iconBoxSize = 40;

  static const double dividerInset =
      AppDimensions.spacing16 + iconBoxSize + AppDimensions.spacing12;

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
    final ink = AppColors.readableAccent(color, isDark: widget.isDark);
    final launchesExperience =
        widget.activity.kind != CoachActivityKind.guidance;

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
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing16,
            vertical: AppDimensions.spacing12,
          ),
          child: Row(
            children: [
              Container(
                width: CoachActivityCell.iconBoxSize,
                height: CoachActivityCell.iconBoxSize,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimensions.radius12),
                ),
                child: Center(
                  child: Icon(widget.activity.icon, size: 20, color: color),
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.activity.title,
                      style: AppTextStyles.titleSmall(
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacing2),
                    Text(
                      widget.activity.description,
                      style: AppTextStyles.bodySmall(
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.spacing8),
              // Badge de durée en pilule arrondie, à gauche du glyphe.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacing8,
                  vertical: AppDimensions.spacing4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                ),
                child: Text(
                  '${widget.activity.durationMinutes} min',
                  style: AppTextStyles.badge(color: ink),
                ),
              ),
              const SizedBox(width: AppDimensions.spacing4),
              Icon(
                launchesExperience
                    ? Icons.play_arrow_rounded
                    : Icons.chevron_right_rounded,
                color: launchesExperience ? ink : context.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
