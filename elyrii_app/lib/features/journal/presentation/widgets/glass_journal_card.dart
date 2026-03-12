import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../providers/journal_provider.dart';

/// Carte de note avec effet liquid glass
class GlassJournalCard extends StatefulWidget {
  final JournalEntry entry;
  final VoidCallback onTap;
  final bool isDark;

  const GlassJournalCard({
    super.key,
    required this.entry,
    required this.onTap,
    this.isDark = false,
  });

  @override
  State<GlassJournalCard> createState() => _GlassJournalCardState();
}

class _GlassJournalCardState extends State<GlassJournalCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final timeFormat = DateFormat('HH:mm');

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.isDark
                      ? [
                          Colors.white.withValues(alpha: 0.12),
                          Colors.white.withValues(alpha: 0.08),
                        ]
                      : [
                          const Color(0xFFFFFFFF).withValues(alpha: 0.85),
                          const Color(0xFFF5F3FF).withValues(alpha: 0.75),
                        ],
                ),
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                border: Border.all(
                  color: widget.isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : const Color(0xFFE0D4FF).withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: widget.isDark ? 0.4 : 0.15,
                    ),
                    blurRadius: 24,
                    spreadRadius: 0,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Date
                    Text(
                      dateFormat.format(widget.entry.createdAt),
                      style: AppTextStyles.labelSmall(
                        color: widget.isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingSm),
                    // Titre (si présent)
                    if (widget.entry.title.isNotEmpty) ...[
                      Text(
                        widget.entry.title,
                        style: AppTextStyles.titleMedium(
                          color: widget.isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppDimensions.spacingXs),
                    ],
                    // Preview du contenu
                    Text(
                      widget.entry.content ?? '',
                      style: AppTextStyles.bodyMedium(
                        color: widget.isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      maxLines: widget.entry.title.isNotEmpty ? 3 : 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    // Heure
                    Text(
                      timeFormat.format(widget.entry.createdAt),
                      style: AppTextStyles.labelSmall(
                        color: widget.isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
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
