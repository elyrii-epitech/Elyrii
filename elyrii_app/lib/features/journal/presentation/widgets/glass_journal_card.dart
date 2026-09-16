import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../providers/journal_provider.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';

/// Carte d'entrée de journal selon les spécifications Apple HIG.
/// Affiche la date localisée en français (gris tertiaire), une pastille subtile
/// pour l'humeur associée, et un aperçu hiérarchisé du texte avec troncature élégante.
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

  /// Formatage de la date en français (ex : 'mar. 3 sept.') avec repli
  /// déterministe hors ligne si les symboles intl ne sont pas chargés.
  String _formatDate(DateTime date) {
    try {
      return DateFormat('EEE d MMM', 'fr_FR').format(date);
    } catch (_) {
      const days = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
      const months = [
        'janv.',
        'févr.',
        'mars',
        'avr.',
        'mai',
        'juin',
        'juil.',
        'août',
        'sept.',
        'oct.',
        'nov.',
        'déc.',
      ];
      final dayName = days[date.weekday - 1];
      final monthName = months[date.month - 1];
      return '$dayName ${date.day} $monthName';
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final timeStr =
        '${entry.createdAt.hour.toString().padLeft(2, '0')}:${entry.createdAt.minute.toString().padLeft(2, '0')}';
    final moodInfo = _getMoodInfo(entry.mood);

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        ElyriiHaptics.light();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF201E24) : Colors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : const Color(0xFFE0D4FF).withValues(alpha: 0.45),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: widget.isDark ? 0.22 : 0.04,
                ),
                blurRadius: 14,
                spreadRadius: 0,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // En-tête : Date (format FR) + Heure en gris tertiaire et Pastille d'humeur
                Row(
                  children: [
                    Text(
                      _formatDate(entry.createdAt),
                      style: AppTextStyles.labelSmall(
                        color: widget.isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      ' · $timeStr',
                      style: AppTextStyles.labelSmall(
                        color: widget.isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    ),
                    const Spacer(),
                    if (moodInfo != null)
                      _buildMoodBadge(moodInfo, widget.isDark),
                  ],
                ),

                // Titre hiérarchisé (si renseigné)
                if (entry.title.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    entry.title,
                    style: AppTextStyles.titleMedium(
                      color: widget.isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Aperçu du contenu (2-3 lignes avec troncature élégante)
                if ((entry.content ?? '').trim().isNotEmpty) ...[
                  SizedBox(height: entry.title.isNotEmpty ? 6 : 8),
                  Text(
                    entry.content!.trim(),
                    style: AppTextStyles.bodyMedium(
                      color: widget.isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ).copyWith(height: 1.45),
                    maxLines: entry.title.isNotEmpty ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Pastille d'humeur subtile au style iOS (couleur mood + libellé)
  Widget _buildMoodBadge(_MoodBadgeInfo moodInfo, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: moodInfo.color.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: moodInfo.color.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: moodInfo.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            moodInfo.label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: moodInfo.color,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Métadonnées d'une pastille d'humeur
class _MoodBadgeInfo {
  final Color color;
  final String label;

  const _MoodBadgeInfo({required this.color, required this.label});
}

/// Résolution de l'humeur depuis l'identifiant technique ou libellé
_MoodBadgeInfo? _getMoodInfo(String? moodStr) {
  if (moodStr == null || moodStr.trim().isEmpty) return null;
  final normalized = moodStr.trim().toLowerCase();
  switch (normalized) {
    case 'verysad':
    case 'très triste':
    case 'tres triste':
      return const _MoodBadgeInfo(
        color: Color(0xFF7BA3C7),
        label: 'Très triste',
      );
    case 'sad':
    case 'triste':
      return const _MoodBadgeInfo(color: Color(0xFF93B8DA), label: 'Triste');
    case 'neutral':
    case 'neutre':
      return const _MoodBadgeInfo(color: Color(0xFFA39C96), label: 'Neutre');
    case 'happy':
    case 'joyeux':
    case 'content':
      return const _MoodBadgeInfo(color: Color(0xFFA8D5BA), label: 'Joyeux');
    case 'veryhappy':
    case 'très joyeux':
    case 'tres joyeux':
    case 'radieux':
      return const _MoodBadgeInfo(color: Color(0xFF7BC393), label: 'Radieux');
    default:
      return _MoodBadgeInfo(color: AppColors.primary, label: moodStr);
  }
}
