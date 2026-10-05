import 'package:flutter/material.dart';

import 'breath_phase.dart';

enum MeditationCategory {
  breathing('Respiration'),
  mindfulness('Présence'),
  body('Corps'),
  kindness('Bienveillance');

  const MeditationCategory(this.label);
  final String label;
}

class MeditationSource {
  const MeditationSource(this.title, this.url);
  final String title;
  final String url;
}

/// Original written guidance; weights distribute steps over the chosen time.
class MeditationStep {
  const MeditationStep(this.title, this.instruction, {this.weight = 1});
  final String title;
  final String instruction;
  final int weight;
}

class MeditationExercise {
  const MeditationExercise({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.category,
    required this.icon,
    required this.color,
    required this.sources,
    this.breathingType,
    this.steps = const [],
    this.practiceTip = 'Installe-toi confortablement et avance à ton rythme.',
  });

  final String id;
  final String title;
  final String subtitle;
  final String description;
  final MeditationCategory category;
  final IconData icon;
  final Color color;
  final List<MeditationSource> sources;
  final BreathingType? breathingType;
  final List<MeditationStep> steps;
  final String practiceTip;

  bool get isBreathing => breathingType != null;
  String get guidanceLabel => isBreathing ? 'Souffle guidé' : 'Guidage écrit';
}
