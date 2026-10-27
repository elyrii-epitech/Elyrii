import '../theme/app_dimensions.dart';

/// Functional roles for Elyrii Liquid Glass surfaces. Each role calibrates
/// blur, opacity, and refraction to its context.
enum GlassRole {
  /// Dock v2 glass without refraction.
  navigation(blur: AppDimensions.navigationBlur, opacity: 0.66, refraction: 0),

  /// Floating controls, including the mascot button and header actions.
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
