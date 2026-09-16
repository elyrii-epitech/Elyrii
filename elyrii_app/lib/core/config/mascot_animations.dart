import 'package:flutter/foundation.dart';

/// Mode de lecture d'un clip de la mascotte.
enum MascotAnimationMode {
  /// Joué en boucle tant que l'état persiste (idle, attentive, thinking).
  loop,

  /// Joué une seule fois puis retour automatique au calme (greet, celebrate).
  once,

  /// Fige le modèle dans sa pose courante sans changer de clip (pauses).
  hold,
}

/// Clip d'animation embarqué dans `assets/elyrii_velours_animations.glb`.
///
/// Les noms, durées et intentions proviennent du pipeline Blender validé le
/// 2026-09-11 (`art/mascot3d/animation_studies/clips.json` + validation glTF
/// et viewer : 6 clips, 0 erreur, lectures vérifiées dans model-viewer).
@immutable
class MascotAnimation {
  /// Nom exact de l'animation dans le GLB (sensible à la casse).
  final String clipName;

  /// Libellé lisible (usage debug/telemetry).
  final String label;

  final MascotAnimationMode mode;

  /// Durée exacte du clip, utilisée pour programmer le retour au calme
  /// des clips `once` (flutter_3d_controller n'expose pas d'évènement fin).
  final Duration duration;

  const MascotAnimation({
    required this.clipName,
    required this.label,
    required this.mode,
    required this.duration,
  });

  @override
  bool operator ==(Object other) =>
      other is MascotAnimation && other.clipName == clipName;

  @override
  int get hashCode => clipName.hashCode;
}

/// Bibliothèque des clips de la mascotte Elyrii « Velours ».
abstract final class MascotAnimations {
  /// Respiration imperceptible, regard stable, un clignement naturel.
  static const idle = MascotAnimation(
    clipName: 'idle',
    label: 'Présence',
    mode: MascotAnimationMode.loop,
    duration: Duration(seconds: 6),
  );

  /// Coude bas, patte relevée ; un salut souple, puis retour au calme.
  static const greet = MascotAnimation(
    clipName: 'greet',
    label: 'Accueil',
    mode: MascotAnimationMode.once,
    duration: Duration(milliseconds: 3200),
  );

  /// Légère inclinaison bienveillante, petit signe d'acquiescement.
  static const attentive = MascotAnimation(
    clipName: 'attentive',
    label: 'Écoute',
    mode: MascotAnimationMode.loop,
    duration: Duration(milliseconds: 4800),
  );

  /// Regard de côté et retour posé ; aucun tic d'impatience.
  static const thinking = MascotAnimation(
    clipName: 'thinking',
    label: 'Réflexion',
    mode: MascotAnimationMode.loop,
    duration: Duration(milliseconds: 4400),
  );

  /// Bras ouverts et légèrement fléchis, petit signe de satisfaction.
  static const celebrate = MascotAnimation(
    clipName: 'celebrate',
    label: 'Réussite',
    mode: MascotAnimationMode.once,
    duration: Duration(milliseconds: 3400),
  );

  /// Respiration guidée : 0→1 s inspiration, 1→2 s expiration.
  ///
  /// Le pipeline a validé un pilotage par phase (`currentTime`) dans le
  /// harnais web model-viewer ; l'API Flutter de flutter_3d_controller
  /// n'expose pas le seek, le clip est donc joué en boucle continue
  /// pendant la séance — le cercle zen reste le guide précis des phases.
  static const breathe = MascotAnimation(
    clipName: 'breathe',
    label: 'Respiration',
    mode: MascotAnimationMode.loop,
    duration: Duration(seconds: 2),
  );

  /// Sentinel : conserve la pose exacte (pauses de séance).
  static const holdPose = MascotAnimation(
    clipName: '',
    label: 'Pose tenue',
    mode: MascotAnimationMode.hold,
    duration: Duration.zero,
  );
}
