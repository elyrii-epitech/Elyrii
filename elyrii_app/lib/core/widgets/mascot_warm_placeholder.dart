import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Placeholder organique affiché pendant le chargement de la mascotte 3D.
///
/// Flou diffus chaud : dégradé radial translucide aux couleurs de marque
/// (lavande `#7E6AD8` / pêche `#FFB5A8`) avec une pulsation de respiration
/// lente (2400 ms). Remplace l'ancien shimmer gris circulaire : aucune barre
/// de progression, aucun saut de mise en page — le modèle 3D apparaît en
/// fondu enchaîné par-dessus.
class MascotWarmPlaceholder extends StatefulWidget {
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
  State<MascotWarmPlaceholder> createState() => _MascotWarmPlaceholderState();
}

class _MascotWarmPlaceholderState extends State<MascotWarmPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breatheController;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseAlpha = isDark ? 0.20 : 0.14;

    return Center(
      child: AnimatedBuilder(
        animation: _breatheController,
        builder: (context, child) {
          // Respiration lente : halo 1.00 -> 1.08, opacité ±20 %.
          final t = Curves.easeInOutSine.transform(_breatheController.value);
          final scale = 1.0 + t * 0.08;

          return Transform.scale(
            scale: scale,
            child: Opacity(opacity: 0.8 + t * 0.2, child: child),
          );
        },
        child: Container(
          width: widget.width * 0.8,
          height: widget.height * 0.8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.secondary.withValues(alpha: baseAlpha * 0.9),
                AppColors.primary.withValues(alpha: baseAlpha),
                AppColors.primary.withValues(alpha: baseAlpha * 0.35),
                Colors.transparent,
              ],
              stops: const [0.0, 0.45, 0.75, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}
