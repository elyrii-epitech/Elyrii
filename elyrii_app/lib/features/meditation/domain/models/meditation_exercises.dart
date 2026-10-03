import 'package:flutter/material.dart';

import 'breath_phase.dart';
import 'meditation_exercise.dart';

/// Sources describe the practices; the French scripts and timed adaptations
/// are written for Elyrii, not endorsements or clinical protocols.
class MeditationExercises {
  MeditationExercises._();

  static const nhsBreathing = MeditationSource(
    'NHS · Breathing exercises for stress',
    'https://www.nhs.uk/mental-health/self-help/guides-tools-and-activities/breathing-exercises-for-stress/',
  );
  static const vaBreathing = MeditationSource(
    'VA Whole Health · Diaphragmatic breathing',
    'https://www.va.gov/WHOLEHEALTHLIBRARY/tools/diaphragmatic-breathing.asp',
  );
  static const weilBreathing = MeditationSource(
    'Dr Andrew Weil · Breathing exercises',
    'https://www.drweil.com/health-wellness/body-mind-spirit/stress-anxiety/breathing-three-exercises/',
  );
  static const mindfulBreathing = MeditationSource(
    'UC Berkeley · Mindful breathing',
    'https://ggia.berkeley.edu/practice/mindful_breathing',
  );
  static const bodyScan = MeditationSource(
    'UC Berkeley · Body scan meditation',
    'https://ggia.berkeley.edu/practice/body_scan_meditation',
  );
  static const lovingKindness = MeditationSource(
    'UC Berkeley · Loving-kindness meditation',
    'https://ggia.berkeley.edu/practice/loving_kindness_meditation',
  );
  static const selfCompassion = MeditationSource(
    'UC Berkeley · Self-compassion break',
    'https://ggia.berkeley.edu/practice/self_compassion_break',
  );
  static const mindfulness = MeditationSource(
    'NHS · Mindfulness',
    'https://www.nhs.uk/mental-health/self-help/tips-and-support/mindfulness/',
  );
  static const nccih = MeditationSource(
    'NCCIH · Meditation and mindfulness',
    'https://www.nccih.nih.gov/health/meditation-and-mindfulness-effectiveness-and-safety',
  );
  static const nccihYoga = MeditationSource(
    'NCCIH · Yoga: What you need to know',
    'https://www.nccih.nih.gov/health/yoga-what-you-need-to-know',
  );
  static const boxBreathing = MeditationSource(
    'Cleveland Clinic · Box breathing',
    'https://health.clevelandclinic.org/box-breathing-benefits',
  );

  static final List<MeditationExercise> all = List.unmodifiable([
    _breathing(
      BreathingType.facile,
      'Découverte',
      'Souffle doux 3–3',
      'Découvre un rythme court et régulier, sans retenir ton souffle.',
      [nhsBreathing],
    ),
    _breathing(
      BreathingType.coherence,
      'Équilibre',
      'Cohérence 5–5',
      'Inspire et expire sur un même rythme, six fois par minute.',
      [vaBreathing, nhsBreathing],
    ),
    _breathing(
      BreathingType.expirationLongue,
      'Ralentir',
      'Expiration 4–6',
      'Prends le temps d’expirer, avec un repère doux sans rétention.',
      [vaBreathing],
    ),
    _breathing(
      BreathingType.diaphragmatique,
      'Ventre détendu',
      'Respiration ventrale',
      'Pose une main sur ton ventre et observe son mouvement.',
      [vaBreathing],
    ),
    _breathing(
      BreathingType.carree,
      'Focus',
      'Respiration carrée',
      'Quatre phases de même durée pour suivre un repère régulier.',
      [boxBreathing],
      tip:
          'Les rétentions restent confortables. Tu peux choisir une pratique sans rétention.',
    ),
    _breathing(
      BreathingType.relaxation478,
      'Pause 4–7–8',
      'Quatre cycles, puis souffle libre',
      'Après quatre cycles guidés, la séance continue au rythme naturel.',
      [weilBreathing],
      tip:
          'Quatre cycles maximum par séance, suivis d’un temps de respiration libre. Les secondes sont un repère adapté pour Elyrii.',
    ),
    _breathing(
      BreathingType.ujjayi,
      'Souffle océan',
      'Inspiration du yoga',
      'Écoute un souffle légèrement sonore, en gardant la gorge détendue.',
      [nccihYoga],
      tip:
          'Le rythme 6–6 est une adaptation pour le guidage. Garde un souffle facile, sans serrer la gorge.',
    ),
    const MeditationExercise(
      id: 'mindful-breathing',
      title: 'Souffle conscient',
      subtitle: 'Observer, sans contrôler',
      description:
          'Porte ton attention sur le souffle naturel, sans compter les secondes.',
      category: MeditationCategory.mindfulness,
      icon: Icons.spa_rounded,
      color: Color(0xFFA8D5BA),
      sources: [mindfulBreathing],
      steps: [
        MeditationStep(
          'Prendre place',
          'Assieds-toi comme tu es à l’aise. Sens les points de contact avec le siège et le sol. Tu peux garder les yeux ouverts.',
        ),
        MeditationStep(
          'Trouver le souffle',
          'Observe où tu ressens le mieux la respiration : le nez, la poitrine ou le ventre. Laisse le souffle garder son rythme naturel.',
        ),
        MeditationStep(
          'Rester avec lui',
          'Suis une inspiration, puis une expiration. Tu n’as rien à réussir. Observe simplement les sensations qui changent.',
          weight: 3,
        ),
        MeditationStep(
          'Revenir doucement',
          'Si ton attention s’éloigne, remarque-le sans te juger. Reviens à la prochaine respiration.',
          weight: 2,
        ),
        MeditationStep(
          'Terminer',
          'Élargis ton attention à la pièce. Sens tes appuis et prends le temps de reprendre ton activité.',
        ),
      ],
    ),
    const MeditationExercise(
      id: 'body-scan',
      title: 'Scan corporel',
      subtitle: 'Parcourir les sensations',
      description:
          'Déplace ton attention dans le corps, sans chercher à changer ce que tu ressens.',
      category: MeditationCategory.body,
      icon: Icons.accessibility_new_rounded,
      color: Color(0xFF93B8DA),
      sources: [bodyScan],
      steps: [
        MeditationStep(
          'S’installer',
          'Assieds-toi ou allonge-toi confortablement. Observe les zones du corps soutenues par le siège ou le sol.',
        ),
        MeditationStep(
          'Pieds et jambes',
          'Porte ton attention aux pieds, puis aux jambes. Note la température, les contacts ou l’absence de sensation.',
          weight: 2,
        ),
        MeditationStep(
          'Bassin et ventre',
          'Observe le bassin, le ventre et le bas du dos. Laisse la respiration être naturelle.',
          weight: 2,
        ),
        MeditationStep(
          'Poitrine et dos',
          'Remarque les sensations dans la poitrine et le dos. Tu peux rester avec une zone confortable si tu le préfères.',
          weight: 2,
        ),
        MeditationStep(
          'Mains et épaules',
          'Déplace ton attention vers les mains, les bras, puis les épaules. Accueille ce que tu remarques.',
          weight: 2,
        ),
        MeditationStep(
          'Visage et corps entier',
          'Observe la mâchoire et le visage, puis le corps dans son ensemble. Il n’est pas nécessaire de ressentir quelque chose de particulier.',
          weight: 2,
        ),
        MeditationStep(
          'Revenir',
          'Sens tes appuis. Bouge doucement les doigts et prends le temps de retrouver la pièce.',
        ),
      ],
    ),
    const MeditationExercise(
      id: 'sound-awareness',
      title: 'Écoute des sons',
      subtitle: 'Revenir à ce qui est là',
      description:
          'Accueille les sons proches et lointains comme un point d’attention au présent.',
      category: MeditationCategory.mindfulness,
      icon: Icons.hearing_rounded,
      color: Color(0xFFFDD876),
      sources: [mindfulness, nccih],
      steps: [
        MeditationStep(
          'Trouver ses appuis',
          'Assieds-toi confortablement. Remarque tes points de contact. Tu peux laisser les yeux ouverts.',
        ),
        MeditationStep(
          'Écouter autour de soi',
          'Laisse les sons venir à toi. Observe les sons proches, puis ceux qui semblent plus lointains.',
          weight: 3,
        ),
        MeditationStep(
          'Observer leur passage',
          'Remarque un son qui apparaît, change, puis s’éloigne. Il n’est pas nécessaire d’en chercher la cause.',
          weight: 2,
        ),
        MeditationStep(
          'Revenir à l’écoute',
          'Quand une pensée t’emporte, remarque-la simplement. Reviens aux sons, ou aux appuis du corps si c’est plus agréable.',
          weight: 2,
        ),
        MeditationStep(
          'Clore la pause',
          'Sens à nouveau tes appuis. Regarde autour de toi et reprends doucement ton activité.',
        ),
      ],
    ),
    const MeditationExercise(
      id: 'loving-kindness',
      title: 'Bienveillance',
      subtitle: 'Cultiver des souhaits doux',
      description:
          'Adresse-toi des souhaits bienveillants, puis étends-les à une personne de ton choix.',
      category: MeditationCategory.kindness,
      icon: Icons.favorite_border_rounded,
      color: Color(0xFFFFB5A8),
      sources: [lovingKindness],
      steps: [
        MeditationStep(
          'Se poser',
          'Trouve une posture confortable. Remarque le souffle et les appuis, sans les modifier.',
        ),
        MeditationStep(
          'Pour soi',
          'Répète intérieurement, à ton rythme : « Que je sois en sécurité. Que je trouve un peu de paix. Que je prenne soin de moi. »',
          weight: 3,
        ),
        MeditationStep(
          'Pour une personne',
          'Pense à quelqu’un avec qui tu te sens à l’aise. Si tu le souhaites, adresse-lui les mêmes souhaits.',
          weight: 3,
        ),
        MeditationStep(
          'Sans obligation',
          'Il n’y a pas d’émotion à produire. Tu peux rester avec des mots simples ou revenir au souffle.',
          weight: 2,
        ),
        MeditationStep(
          'Terminer',
          'Garde un souhait qui te parle. Sens les points de contact et retrouve doucement la pièce.',
        ),
      ],
    ),
    const MeditationExercise(
      id: 'self-compassion',
      title: 'Auto-compassion',
      subtitle: 'Se parler avec douceur',
      description:
          'Fais une pause pour reconnaître ce que tu vis et t’adresser un peu de soutien.',
      category: MeditationCategory.kindness,
      icon: Icons.volunteer_activism_rounded,
      color: Color(0xFFA99AF0),
      sources: [selfCompassion],
      steps: [
        MeditationStep(
          'S’ancrer',
          'Sens les pieds ou les points de contact. Choisis une difficulté légère du quotidien, ou reste simplement avec ce que tu ressens.',
        ),
        MeditationStep(
          'Reconnaître',
          'Tu peux te dire : « Ce moment est difficile pour moi. » Remarque ce qui est présent, sans te demander de le résoudre maintenant.',
          weight: 2,
        ),
        MeditationStep(
          'Se sentir humain',
          'Rappelle-toi que les difficultés font partie de l’expérience humaine. D’autres personnes vivent aussi des moments imparfaits.',
          weight: 2,
        ),
        MeditationStep(
          'S’offrir du soutien',
          'Demande-toi : « De quoi ai-je besoin maintenant ? » Adresse-toi une phrase simple, comme tu le ferais pour une personne proche.',
          weight: 3,
        ),
        MeditationStep(
          'Revenir',
          'Sens tes appuis et regarde autour de toi. Tu peux emporter cette phrase de soutien dans la suite de ta journée.',
        ),
      ],
    ),
  ]);

  static MeditationExercise _breathing(
    BreathingType type,
    String title,
    String subtitle,
    String description,
    List<MeditationSource> sources, {
    String tip =
        'Le rythme est un repère : garde un souffle confortable, sans chercher à remplir les poumons au maximum.',
  }) => MeditationExercise(
    id: type.name,
    title: title,
    subtitle: subtitle,
    description: description,
    category: MeditationCategory.breathing,
    icon: type.icon,
    color: type.color,
    sources: sources,
    breathingType: type,
    practiceTip: tip,
  );

  static MeditationExercise forBreathingType(BreathingType type) =>
      all.firstWhere((exercise) => exercise.breathingType == type);
}
