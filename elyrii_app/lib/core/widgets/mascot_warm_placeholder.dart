import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Placeholder affiché pendant le chargement de la mascotte 3D.
///
/// Silhouette plate et immobile : un disque translucide aux couleurs de
/// marque, sans halo, sans respiration. Le modèle 3D apparaît en fondu
/// enchaîné par-dessus ; en cas d'échec, cette forme reste la pose de repos.
class MascotWarmPlaceholder extends StatelessWidget {
  /// Largeur de la zone de chargement.
  final double width;

  /// Hauteur de la zone de chargement.
  final double height;

  const MascotWarmPlaceholder({
    super.key,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseAlpha = isDark ? 0.20 : 0.14;

    return Center(
      child: Container(
        width: width * 0.8,
        height: height * 0.8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary.withValues(alpha: baseAlpha),
        ),
      ),
    );
  }
}
