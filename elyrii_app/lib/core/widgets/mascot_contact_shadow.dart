import 'package:flutter/material.dart';

/// Ground contact shadow beneath the mascot, providing soft ambient occlusion.
/// A black/charcoal-to-transparent radial ellipse changes with elevation: it
/// widens and fades as the mascot rises, then tightens and darkens as it
/// descends, following Apple-style spatial behavior without a circular
/// enclosure.
class MascotContactShadow extends StatelessWidget {
  /// Maximum ground-shadow width when the mascot is closest to the ground.
  final double width;

  /// Normalized character elevation: 0 is resting, 1 is the highest point.
  final double elevation;

  /// Darkens the shadow in dark mode to preserve visible grounding.
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
