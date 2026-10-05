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
/// Courbes reproductibles : `scripts/mascot/build_velours_motion.py`.
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

/// Bibliothèque native d'Elyrii. Les noms et durées sont vérifiés contre
/// le GLB par `scripts/mascot/check_velours_motion.py`.
abstract final class MascotAnimations {
  /// Deux souffles discrets, regard vivant et clignements espacés.
  static const idle = MascotAnimation(
    clipName: 'idle',
    label: "Présence",
    mode: MascotAnimationMode.loop,
    duration: Duration(milliseconds: 12000),
  );

  /// Anticipation, patte relevée, deux salutations du poignet.
  static const greet = MascotAnimation(
    clipName: 'greet',
    label: "Bonjour !",
    mode: MascotAnimationMode.once,
    duration: Duration(milliseconds: 3200),
  );

  /// Inclinaison, légère avancée et petit acquiescement.
  static const attentive = MascotAnimation(
    clipName: 'attentive',
    label: "Je t’écoute",
    mode: MascotAnimationMode.loop,
    duration: Duration(milliseconds: 6400),
  );

  /// Regard en biais, oreille en retard, retour vers toi.
  static const thinking = MascotAnimation(
    clipName: 'thinking',
    label: "Je réfléchis",
    mode: MascotAnimationMode.loop,
    duration: Duration(milliseconds: 4400),
  );

  /// Les deux pattes s’ouvrent avec un petit rebond du buste.
  static const celebrate = MascotAnimation(
    clipName: 'celebrate',
    label: "Bravo !",
    mode: MascotAnimationMode.once,
    duration: Duration(milliseconds: 3400),
  );

  /// Pose pilotée par la progression réelle de la respiration.
  static const breathe = MascotAnimation(
    clipName: 'breathe',
    label: "Respirons",
    mode: MascotAnimationMode.loop,
    duration: Duration(milliseconds: 2000),
  );

  /// Regard à gauche puis à droite, tête penchée et oreille curieuse.
  static const curious = MascotAnimation(
    clipName: 'curious',
    label: "Tiens, tiens…",
    mode: MascotAnimationMode.once,
    duration: Duration(milliseconds: 7200),
  );

  /// Long clignement paisible et relâchement des épaules.
  static const cozy = MascotAnimation(
    clipName: 'cozy',
    label: "Bien installé",
    mode: MascotAnimationMode.once,
    duration: Duration(milliseconds: 8000),
  );

  /// Un signe de tête posé après une réponse ou une humeur partagée.
  static const acknowledge = MascotAnimation(
    clipName: 'acknowledge',
    label: "Je suis là",
    mode: MascotAnimationMode.once,
    duration: Duration(milliseconds: 2600),
  );

  /// La tête s’approche, une patte s’ouvre doucement pour accueillir.
  static const reassure = MascotAnimation(
    clipName: 'reassure',
    label: "À ton rythme",
    mode: MascotAnimationMode.once,
    duration: Duration(milliseconds: 4800),
  );

  /// Deux accents de joie contenus, pattes ouvertes et yeux plissés.
  static const delight = MascotAnimation(
    clipName: 'delight',
    label: "Petit bonheur",
    mode: MascotAnimationMode.once,
    duration: Duration(milliseconds: 3600),
  );

  /// Se penche vers toi, ferme les yeux et se redresse doucement.
  static const nuzzle = MascotAnimation(
    clipName: 'nuzzle',
    label: "Un peu de douceur",
    mode: MascotAnimationMode.once,
    duration: Duration(milliseconds: 4000),
  );

  /// Buste redressé, petit regard de chaque côté et salut du poignet.
  static const proud = MascotAnimation(
    clipName: 'proud',
    label: "Ça me va ?",
    mode: MascotAnimationMode.once,
    duration: Duration(milliseconds: 3800),
  );

  /// Étirement asymétrique des pattes, yeux mi-clos, relâchement.
  static const stretch = MascotAnimation(
    clipName: 'stretch',
    label: "Petite pause",
    mode: MascotAnimationMode.once,
    duration: Duration(milliseconds: 5600),
  );

  /// Une longue expiration et un léger signe de tête après la séance.
  static const settle = MascotAnimation(
    clipName: 'settle',
    label: "Tout doucement",
    mode: MascotAnimationMode.once,
    duration: Duration(milliseconds: 5200),
  );

  /// Une patte invite à avancer, suivie d’un acquiescement.
  static const invite = MascotAnimation(
    clipName: 'invite',
    label: "On y va ?",
    mode: MascotAnimationMode.once,
    duration: Duration(milliseconds: 3400),
  );

  /// Conserve la pose courante pendant une pause.
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
