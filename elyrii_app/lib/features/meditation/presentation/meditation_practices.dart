import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/models/breath_phase.dart';
import '../domain/models/meditation_exercise.dart';
import '../domain/models/meditation_exercises.dart';

class MeditationPractice {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final List<int> durations;

  const MeditationPractice(
    this.id,
    this.title,
    this.subtitle,
    this.description,
    this.icon,
    this.color,
    this.durations,
  );

  MeditationExercise get exercise =>
      MeditationExercises.all.firstWhere((exercise) => exercise.id == id);
  String get rhythm =>
      exercise.breathingType?.phases.map((phase) => phase.seconds).join('·') ??
      'Guidage écrit';

  List<int> get rhythmSeconds {
    final phases = exercise.breathingType?.phases ?? const <BreathPhase>[];
    final result = <int>[0, 0, 0, 0];
    var exhaled = false;
    for (final phase in phases) {
      switch (phase.action) {
        case BreathAction.expand:
          result[0] = phase.seconds;
        case BreathAction.contract:
          result[2] = phase.seconds;
          exhaled = true;
        case BreathAction.hold:
          result[exhaled ? 3 : 1] = phase.seconds;
      }
    }
    return result;
  }

  static const durationsAvailable = [3, 5, 10, 15];
  static const all = [
    MeditationPractice(
      'coherence',
      'Cohérence cardiaque',
      'Un souffle régulier',
      'Un rythme régulier pour ralentir et te poser avant la nuit.',
      Symbols.favorite_rounded,
      AppColors.meditationTeal,
      [5, 10, 15],
    ),
    MeditationPractice(
      'facile',
      'Découverte',
      'Souffle doux 3–3',
      'Suis un rythme de trois secondes à l’inspiration et à l’expiration.',
      Symbols.eco_rounded,
      AppColors.meditationGreen,
      [3, 5, 10],
    ),
    MeditationPractice(
      'carree',
      'Respiration carrée',
      'Respiration carrée',
      'Quatre temps égaux pour ramener doucement ton attention ici.',
      Symbols.crop_square_rounded,
      AppColors.meditationViolet,
      [3, 5, 10, 15],
    ),
    MeditationPractice(
      'mindful-breathing',
      'Souffle conscient',
      'Observer, sans contrôler',
      'Observe ton souffle comme il vient, sans chercher à le changer.',
      Symbols.air_rounded,
      AppColors.meditationGreen,
      [3, 5, 10, 15],
    ),
    MeditationPractice(
      'body-scan',
      'Scan corporel',
      'Parcourir les sensations',
      "Porte ton attention sur les sensations, du visage jusqu'aux pieds.",
      Symbols.accessibility_new_rounded,
      AppColors.meditationPink,
      [5, 10, 15],
    ),
    MeditationPractice(
      'relaxation478',
      'Relaxation 4-7-8',
      'Quatre cycles, puis souffle libre',
      'Allonge ton expiration sans forcer. Après quatre cycles guidés, retrouve ton souffle naturel.',
      Symbols.bedtime_rounded,
      AppColors.meditationPink,
      [3, 5, 10],
    ),
    MeditationPractice(
      'diaphragmatique',
      'Respiration ventrale',
      'Respirer avec le ventre',
      'Observe le mouvement de ton ventre pendant la respiration.',
      Symbols.pulmonology_rounded,
      AppColors.meditationOrange,
      [3, 5, 10, 15],
    ),
    MeditationPractice(
      'ujjayi',
      'Respiration Ujjayi',
      'Un souffle comme une vague',
      'Laisse ton souffle retrouver un rythme doux, en gardant la gorge détendue.',
      Symbols.waves_rounded,
      AppColors.meditationViolet,
      [5, 10, 15],
    ),
    MeditationPractice(
      'expirationLongue',
      'Expiration longue',
      'Souffler plus longtemps',
      "Suis un rythme où l’expiration dure plus longtemps que l’inspiration.",
      Symbols.air_rounded,
      AppColors.meditationTeal,
      [3, 5, 10, 15],
    ),
  ];

  static MeditationPractice? forId(String id) {
    for (final practice in all) {
      if (practice.id == id) return practice;
    }
    return null;
  }

  static const curation =
      <int, ({String featured, List<List<String>> shelves})>{
        3: (
          featured: 'expirationLongue',
          shelves: [
            ['relaxation478', 'expirationLongue'],
            ['facile', 'mindful-breathing', 'diaphragmatique'],
            ['carree', 'mindful-breathing'],
          ],
        ),
        5: (
          featured: 'coherence',
          shelves: [
            ['relaxation478', 'coherence', 'body-scan'],
            ['expirationLongue', 'facile', 'diaphragmatique'],
            ['carree', 'mindful-breathing', 'ujjayi'],
          ],
        ),
        10: (
          featured: 'body-scan',
          shelves: [
            ['body-scan', 'relaxation478', 'coherence'],
            ['expirationLongue', 'diaphragmatique', 'facile'],
            ['mindful-breathing', 'carree', 'ujjayi'],
          ],
        ),
        15: (
          featured: 'coherence',
          shelves: [
            ['coherence', 'body-scan'],
            ['diaphragmatique', 'expirationLongue'],
            ['mindful-breathing', 'carree', 'ujjayi'],
          ],
        ),
      };
}

String meditationPhaseLabel(List<BreathPhase> phases, int index) {
  if (index < 0) return 'Souffle libre';
  final phase = phases[index];
  return phase.action == BreathAction.hold &&
          index > 0 &&
          phases[index - 1].action == BreathAction.contract
      ? 'Pause'
      : phase.label;
}
