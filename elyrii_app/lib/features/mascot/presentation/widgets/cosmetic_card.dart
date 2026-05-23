import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';

/// Composant de carte premium pour la boutique de skins de la mascotte Elyrii.
/// Propose un design en verre poli (Glassmorphism) avec retour haptique intégré.
class CosmeticCard extends StatelessWidget {
  final String name;
  final String price;
  final bool isUnlocked;
  final bool isEquipped;
  final String assetThumbnail;
  final Color baseColor;
  final VoidCallback onTap;

  const CosmeticCard({
    super.key,
    required this.name,
    required this.price,
    required this.isUnlocked,
    required this.isEquipped,
    required this.assetThumbnail,
    required this.baseColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        width: 160,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isEquipped
                ? [
                    AppColors.primary.withValues(alpha: 0.35),
                    AppColors.accent.withValues(alpha: 0.25),
                  ]
                : [
                    (isDark ? AppColors.cardDark : AppColors.cardLight).withValues(alpha: 0.8),
                    (isDark ? AppColors.cardDark : AppColors.cardLight).withValues(alpha: 0.5),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isEquipped
                ? AppColors.primary.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.15),
            width: isEquipped ? 2.5 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isEquipped
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: isEquipped ? 16 : 8,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Fond décoratif lumineux
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: baseColor.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: baseColor.withValues(alpha: 0.25),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
            ),

            // Contenu de la carte
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icône/Aperçu visuel du skin
                  Expanded(
                    child: Center(
                      child: Hero(
                        tag: 'cosmetic_$name',
                        child: Container(
                          width: 85,
                          height: 85,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.2),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              assetThumbnail,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback élégant en cas d'image manquante
                                return Icon(
                                  Icons.palette_rounded,
                                  size: 40,
                                  color: baseColor,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Titre du skin
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Ligne inférieure : Prix ou statut d'équipement
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Badge prix / débloqué
                      if (!isUnlocked)
                        Row(
                          children: [
                            const Icon(
                              Icons.monetization_on_rounded,
                              size: 16,
                              color: Color(0xFFFFD700), // Couleur or chaleureuse
                            ),
                            const SizedBox(width: 4),
                            Text(
                              price,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFFD700),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          isEquipped ? "Équipé" : "Débloqué",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isEquipped
                                ? AppColors.primary
                                : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                          ),
                        ),

                      // Icône d'action rapide
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isEquipped
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          !isUnlocked
                              ? Icons.lock_outline_rounded
                              : (isEquipped ? Icons.check_rounded : Icons.arrow_forward_rounded),
                          size: 14,
                          color: isEquipped
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
