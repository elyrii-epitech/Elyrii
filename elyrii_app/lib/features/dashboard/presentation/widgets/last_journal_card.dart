import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../providers/dashboard_provider.dart';

/// Carte affichant la dernière entrée du journal avec mood
class LastJournalCard extends StatefulWidget {
  final String? title;
  final String? content;
  final MoodType? mood;
  final DateTime? createdAt;
  final bool isDark;
  final VoidCallback? onTap;

  const LastJournalCard({
    super.key,
    this.title,
    this.content,
    this.mood,
    this.createdAt,
    this.isDark = false,
    this.onTap,
  });

  @override
  State<LastJournalCard> createState() => _LastJournalCardState();
}

class _LastJournalCardState extends State<LastJournalCard> {
  bool _isPressed = false;

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'à l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'il y a ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else {
      return DateFormat('dd MMM', 'fr_FR').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasEntry = widget.content != null || widget.title != null;

    return GestureDetector(
      onTapDown: (_) {
        if (hasEntry) {
          setState(() => _isPressed = true);
          HapticFeedback.lightImpact();
        }
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        if (hasEntry) widget.onTap?.call();
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
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.paddingMd),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.isDark
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
                    color: widget.isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: hasEntry ? _buildEntryContent() : _buildEmptyState(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEntryContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header avec icône et label
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('📓', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: AppDimensions.spacingSm),
            Text(
              'Dernière entrée',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: widget.isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
            ),
            const Spacer(),
            // Mood + Time
            if (widget.mood != null)
              Text(widget.mood!.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            if (widget.createdAt != null)
              Text(
                _getTimeAgo(widget.createdAt!),
                style: TextStyle(
                  fontSize: 12,
                  color: widget.isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        // Titre
        if (widget.title != null && widget.title!.isNotEmpty)
          Text(
            widget.title!,
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
        if (widget.title != null && widget.title!.isNotEmpty)
          const SizedBox(height: 4),
        // Contenu preview
        if (widget.content != null && widget.content!.isNotEmpty)
          Text(
            widget.content!,
            style: TextStyle(
              fontSize: 14,
              color: widget.isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text('📓', style: TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: AppDimensions.spacingMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aucune entrée récente',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: widget.isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Commence à écrire tes pensées',
                style: TextStyle(
                  fontSize: 13,
                  color: widget.isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: widget.isDark
              ? AppColors.textTertiaryDark
              : AppColors.textTertiaryLight,
        ),
      ],
    );
  }
}
