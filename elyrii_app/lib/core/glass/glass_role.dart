import '../theme/app_dimensions.dart';

/// Rôles fonctionnels pour les surfaces Liquid Glass dans Elyrii.
///
/// Chaque rôle applique un degré de flou, d'opacité et de réfraction
/// strictement calibré pour son contexte d'utilisation.
enum GlassRole {
  /// Verre v2 du dock, sans réfraction.
  navigation(blur: AppDimensions.navigationBlur, opacity: 0.66, refraction: 0),

  /// Commandes flottantes (bouton mascotte, actions d'en-tête)
  floatingControl(blur: 16.0, opacity: 0.75, refraction: 0.08);

  final double blur;
  final double opacity;
  final double refraction;

  const GlassRole({
    required this.blur,
    required this.opacity,
    required this.refraction,
  });
}
