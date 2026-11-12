import 'package:flutter/foundation.dart';

/// Playback mode for a mascot clip.
enum MascotAnimationMode {
  /// Loops while the state persists: idle, attentive, or thinking.
  loop,

  /// Plays once, then automatically returns to idle: greet or celebrate.
  once,

  /// Freezes the current pose without changing clips, for pauses.
  hold,
}

/// Animation clip bundled in the optimized mascot models.
@immutable
class MascotAnimation {
  /// Exact, case-sensitive animation name in the GLB.
  final String clipName;

  /// Readable label for debugging and telemetry.
  final String label;

  final MascotAnimationMode mode;

  /// Exact clip duration, used to schedule the return to idle for `once` clips
  /// because flutter_3d_controller exposes no completion event.
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

/// Elyrii's native animation library. Names and durations are checked against
/// the GLB by `scripts/mascot/check_velours_motion.py`.
abstract final class MascotAnimations {
  /// Deep breathing, gentle looks, rocking paws, and trembling ears.
  static const idle = MascotAnimation(
    clipName: 'idle',
    label: "Présence",
    mode: MascotAnimationMode.loop,
    duration: Duration(milliseconds: 12000),
  );

  /// Anticipation, a raised paw, and two wrist waves.
  static const greet = MascotAnimation(
    clipName: 'greet',
    label: "Bonjour !",
    mode: MascotAnimationMode.once,
    duration: Duration(milliseconds: 3200),
  );

  /// A lean, a small step forward, and a slight nod.
  static const attentive = MascotAnimation(
    clipName: 'attentive',
    label: "Je t’écoute",
    mode: MascotAnimationMode.loop,
    duration: Duration(milliseconds: 6400),
  );

  /// Sideways look, delayed ear movement, then turns back toward the user.
  static const thinking = MascotAnimation(
    clipName: 'thinking',
    label: "Je réfléchis",
    mode: MascotAnimationMode.loop,
    duration: Duration(milliseconds: 4400),
  );

  /// Both paws open with a small torso bounce.
  static const celebrate = MascotAnimation(
    clipName: 'celebrate',
    label: "Bravo !",
    mode: MascotAnimationMode.once,
    duration: Duration(milliseconds: 3400),
  );

  /// Pose driven by actual breathing progress.
  static const breathe = MascotAnimation(
    clipName: 'breathe',
    label: "Respirons",
    mode: MascotAnimationMode.loop,
    duration: Duration(milliseconds: 2000),
  );

  /// Looks left and right, tilts its head, and raises a curious ear.
  static const curious = MascotAnimation(
    clipName: 'curious',
    label: "Tiens, tiens…",
    mode: MascotAnimationMode.once,
    duration: Duration(milliseconds: 7200),
  );

  /// A long peaceful blink and relaxed shoulders.
  static const cozy = MascotAnimation(
    clipName: 'cozy',
    label: "Bien installé",
    mode: MascotAnimationMode.once,
    duration: Duration(milliseconds: 8000),
  );

  /// A calm nod after a reply or shared mood.
  static const acknowledge = MascotAnimation(
    clipName: 'acknowledge',
    label: "Je suis là",
    mode: MascotAnimationMode.once,
    duration: Duration(milliseconds: 2600),
  );

  /// The head moves closer and a paw opens gently in welcome.
  static const reassure = MascotAnimation(
    clipName: 'reassure',
    label: "À ton rythme",
    mode: MascotAnimationMode.once,
    duration: Duration(milliseconds: 4800),
  );

  /// Two restrained joyful accents, with open paws and narrowed eyes.
  static const delight = MascotAnimation(
    clipName: 'delight',
    label: "Petit bonheur",
    mode: MascotAnimationMode.once,
    duration: Duration(milliseconds: 3600),
  );

  /// Leans toward the user, closes its eyes, and gently straightens up.
  static const nuzzle = MascotAnimation(
    clipName: 'nuzzle',
    label: "Un peu de douceur",
    mode: MascotAnimationMode.once,
    duration: Duration(milliseconds: 4000),
  );

  /// Upright torso, a glance to each side, and a wrist wave.
  static const proud = MascotAnimation(
    clipName: 'proud',
    label: "Ça me va ?",
    mode: MascotAnimationMode.once,
    duration: Duration(milliseconds: 3800),
  );

  /// Asymmetric paw stretch, half-closed eyes, then release.
  static const stretch = MascotAnimation(
    clipName: 'stretch',
    label: "Petite pause",
    mode: MascotAnimationMode.once,
    duration: Duration(milliseconds: 5600),
  );

  /// A long exhale and a slight nod after the session.
  static const settle = MascotAnimation(
    clipName: 'settle',
    label: "Tout doucement",
    mode: MascotAnimationMode.once,
    duration: Duration(milliseconds: 5200),
  );

  /// One paw invites the user forward, followed by a nod.
  static const invite = MascotAnimation(
    clipName: 'invite',
    label: "On y va ?",
    mode: MascotAnimationMode.once,
    duration: Duration(milliseconds: 3400),
  );

  /// Preserves the current pose during a pause.
  static const holdPose = MascotAnimation(
    clipName: '',
    label: 'Pose tenue',
    mode: MascotAnimationMode.hold,
    duration: Duration.zero,
  );

  static const all = <MascotAnimation>[
    idle,
    greet,
    attentive,
    thinking,
    celebrate,
    breathe,
    curious,
    cozy,
    acknowledge,
    reassure,
    delight,
    nuzzle,
    proud,
    stretch,
    settle,
    invite,
  ];
}
