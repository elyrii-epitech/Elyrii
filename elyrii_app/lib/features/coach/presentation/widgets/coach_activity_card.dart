import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass/liquid_glass_kit.dart';
import '../../data/models/coach_model.dart';

/// Carte d'activité du catalogue exploratoire : icône squircle, durée,
/// titre, description et catégorie. Le glyphe de lecture distingue les
/// expériences qui se lancent nativement au tap.
class CoachActivityCard extends StatefulWidget {
  final CoachActivity activity;
  final bool isDark;
  final VoidCallback onTap;

  const CoachActivityCard({
    super.key,
    required this.activity,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<CoachActivityCard> createState() => _CoachActivityCardState();
}

class _CoachActivityCardState extends State<CoachActivityCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.activity.category.color;
    final launchesExperience = widget.activity.kind != CoachActivityKind.guidance;

    return Semantics(
      label: widget.activity.title,
      hint: 'Activité de ${widget.activity.durationMinutes} minutes',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: LiquidGlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(
                          widget.activity.icon,
                          size: 18,
                          color: color,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (launchesExperience) ...[
                            Icon(
                              Icons.play_arrow_rounded,
                              size: 11,
                              color: color,
                            ),
                            const SizedBox(width: 2),
                          ],
                          Text(
                            '${widget.activity.durationMinutes} min',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.activity.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
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
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(widget.activity.category.icon, size: 12, color: color),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.activity.category.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
