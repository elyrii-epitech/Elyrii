/// Rôles fonctionnels pour les surfaces Liquid Glass dans Elyrii.
///
/// Chaque rôle applique un degré de flou, d'opacité et de réfraction
/// strictement calibré pour son contexte d'utilisation.
enum GlassRole {
  /// Barre de navigation inférieure flottante
  navigation(blur: 20.0, opacity: 0.72, refraction: 0.10),

  /// Commandes flottantes (bouton mascotte, actions d'en-tête)
  floatingControl(blur: 16.0, opacity: 0.75, refraction: 0.08),

  /// Modales et feuilles inférieures (Bottom Sheets)
  modalSheet(blur: 24.0, opacity: 0.82, refraction: 0.12),

  /// Dialogues contextuels
  dialog(blur: 20.0, opacity: 0.85, refraction: 0.10);

  final double blur;
  final double opacity;
  final double refraction;

  const GlassRole({
    required this.blur,
    required this.opacity,
    required this.refraction,
  });
}
