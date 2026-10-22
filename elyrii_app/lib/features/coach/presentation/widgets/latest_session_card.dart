import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_kit.dart';
import '../../../../routes/app_routes.dart';
import '../../data/models/coach_model.dart';

/// Dernier échange avec le coach IA : horodatage relatif, réponse
/// dépliable au tap et passerelle vers la conversation continue avec
/// Elyrii (chatbot).
class LatestSessionCard extends StatefulWidget {
  final CoachSession session;
  final bool isDark;

  const LatestSessionCard({
    super.key,
    required this.session,
    required this.isDark,
  });

  @override
  State<LatestSessionCard> createState() => _LatestSessionCardState();
}

class _LatestSessionCardState extends State<LatestSessionCard> {
  bool _expanded = false;

  /// Horodatage relatif en français, sans dépendance externe.
  static String _relativeTime(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'à l\'instant';
    if (difference.inMinutes < 60) return 'il y a ${difference.inMinutes} min';
    if (difference.inHours < 24) return 'il y a ${difference.inHours} h';
    if (difference.inDays == 1) return 'hier';
    return 'il y a ${difference.inDays} jours';
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = context.textPrimary;
    final subtitleColor = context.textSecondary;

    return LiquidGlassCard(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.accent),
              const SizedBox(width: AppDimensions.spacing8),
              Expanded(
                child: Text(
                  'Ton dernier échange',
                  style: AppTextStyles.titleSmall(color: textColor),
                ),
              ),
              Text(
                _relativeTime(widget.session.createdAt),
                style: AppTextStyles.labelSmall(color: context.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing8),
          // Réponse bornée à cinq lignes, dépliable au tap : la page reste
          // calme, le détail reste à un geste.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Text(
                widget.session.response,
                style: AppTextStyles.bodySmall(color: subtitleColor),
                maxLines: _expanded ? null : 5,
                overflow: _expanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacing4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            child: Text(
              _expanded ? 'Réduire' : 'Lire la suite',
              style: AppTextStyles.labelMedium(
                color: AppColors.readableAccent(
                  AppColors.primary,
                  isDark: Theme.of(context).brightness == Brightness.dark,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacing12),
          Divider(
            height: 1,
            thickness: 0.5,
            color: widget.isDark
                ? AppColors.dividerDark
                : AppColors.dividerLight,
          ),
          const SizedBox(height: AppDimensions.spacing12),
          // Passerelle vers la conversation continue : le coach écrit, le
          // chatbot écoute.
          Semantics(
            label: 'Parler à Elyrii',
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.go(AppRoutes.chatbot),
              child: Row(
                children: [
                  Icon(
                    Icons.forum_rounded,
                    size: 16,
                    color: context.textSecondary,
                  ),
                  const SizedBox(width: AppDimensions.spacing8),
                  Expanded(
                    child: Text(
                      'Continuer la conversation',
                      style: AppTextStyles.labelMedium(color: subtitleColor),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: context.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
