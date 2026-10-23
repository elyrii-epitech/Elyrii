import 'package:flutter/material.dart';

/// Ombre de contact au sol sous la mascotte (occlusion ambiante douce).
///
/// Ellipse de dégradé radial noir/anthracite vers transparent. La taille et
/// l'opacité réagissent à l'élévation du personnage : quand la mascotte
/// s'élève, l'ombre s'élargit et s'atténue ; quand elle descend, l'ombre se
/// resserre et s'assombrit — physique spatiale Apple, sans cage circulaire.
class MascotContactShadow extends StatelessWidget {
  /// Largeur maximale de l'ombre au sol (mascotte au plus près du sol).
  final double width;

  /// Élévation normalisée du personnage : 0 = posé, 1 = au plus haut.
  final double elevation;

  /// Assombrit l'ombre en mode sombre pour garder un ancrage lisible.
  final bool isDark;

  const MascotContactShadow({
    super.key,
    required this.width,
    required this.elevation,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = elevation.clamp(0.0, 1.0);

    // Élevée -> ombre large et faible ; posée -> ombre serrée et marquée.
    final spread = 1.0 + clamped * 0.35;
    final baseAlpha = (isDark ? 0.35 : 0.12) * (1.0 - clamped * 0.55);

    return Container(
      width: width * spread,
      height: width * 0.22,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          radius: 0.5,
          colors: [
            Colors.black.withValues(alpha: baseAlpha),
            Colors.black.withValues(alpha: baseAlpha * 0.45),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
    );
  }
}
