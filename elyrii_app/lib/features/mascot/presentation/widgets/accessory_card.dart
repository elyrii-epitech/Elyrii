import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';

/// Définition d'un accessoire cosmétique de la mascotte.
class AccessoryDef {
  final String id;
  final String name;
  final String emoji;

  /// Famille d'accessoires (ex. « Tête », « Visage ») : pilote le filtrage
  /// de l'atelier de personnalisation quand plusieurs catégories existent.
  final String category;

  /// Nombre de défis à compléter pour débloquer cet accessoire.
  final int requiredChallenges;

  const AccessoryDef({
    required this.id,
    required this.name,
    required this.emoji,
    this.category = 'Tête',
    this.requiredChallenges = 0,
  });
}

/// Carte d'affichage d'un accessoire de mascotte (débloqué, verrouillé, équipé).
class AccessoryCard extends StatelessWidget {
  final String name;
  final String emoji;
  final bool isEquipped;
  final bool isLocked;
  final int requiredChallenges;
  final int completedChallenges;
  final bool isDark;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback onLockedTap;

  const AccessoryCard({
    super.key,
    required this.name,
    required this.emoji,
    required this.isEquipped,
    required this.isLocked,
    required this.requiredChallenges,
    required this.completedChallenges,
    required this.isDark,
    required this.accentColor,
    required this.onTap,
    required this.onLockedTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final subtitleColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final tertiaryColor = isDark
        ? AppColors.textTertiaryDark
        : AppColors.textTertiaryLight;

    final progress = requiredChallenges > 0
        ? (completedChallenges / requiredChallenges).clamp(0.0, 1.0)
        : 1.0;

    return GestureDetector(
      onTap: isLocked ? onLockedTap : onTap,
      child: LiquidGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        color: isEquipped
            ? accentColor.withValues(alpha: isDark ? 0.16 : 0.12)
            : null,
        borderColor: isEquipped ? accentColor.withValues(alpha: 0.45) : null,
        child: Row(
          children: [
            _buildEmojiCircle(tertiaryColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: AppTextStyles.titleSmall(
                            color: isLocked
                                ? textColor
                                : (isEquipped ? accentColor : textColor),
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusPill(),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (isLocked) ...[
                    Text(
                      'Termine $requiredChallenges défi pour débloquer',
                      style: AppTextStyles.labelSmall(color: tertiaryColor),
                    ),
                    const SizedBox(height: 10),
                    // Progression arrondie façon iOS : piste fine et
                    // remplissage aux couleurs du thème, sans widget
                    // Material.
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 6,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: Container(
                            color: accentColor.withValues(
                              alpha: isDark ? 0.9 : 0.8,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$completedChallenges / $requiredChallenges défi',
                      style: AppTextStyles.labelSmall(
                        color: tertiaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else
                    Text(
                      isEquipped
                          ? 'Touche pour retirer'
                          : 'Touche pour équiper',
                      style: AppTextStyles.labelSmall(color: subtitleColor),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiCircle(Color tertiaryColor) {
    if (isLocked) {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: 0.25,
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.surfaceDark : AppColors.cardLight,
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                    width: 0.5,
                  ),
                ),
                child: Icon(Icons.lock_rounded, size: 12, color: tertiaryColor),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            accentColor.withValues(alpha: 0.30),
            accentColor.withValues(alpha: 0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.7, 1.0],
        ),
        border: Border.all(
          color: isEquipped
              ? accentColor.withValues(alpha: 0.6)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
    );
  }

  Widget _buildStatusPill() {
    if (isLocked) {
      return _pill(
        label: 'Verrouillé',
        icon: Icons.lock_rounded,
        color: isDark
            ? AppColors.textTertiaryDark
            : AppColors.textTertiaryLight,
        filled: false,
      );
    }
    if (isEquipped) {
      return _pill(
        label: 'Équipé',
        icon: Icons.check_circle_rounded,
        color: accentColor,
        filled: true,
      );
    }
    return _pill(
      label: 'Débloqué',
      icon: Icons.workspace_premium_rounded,
      color: isDark ? AppColors.accentDark : AppColors.successDark,
      filled: true,
    );
  }

  Widget _pill({
    required String label,
    required IconData icon,
    required Color color,
    required bool filled,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled
            ? color.withValues(alpha: isDark ? 0.18 : 0.14)
            : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03)),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: filled ? 0.4 : 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
