import 'package:flutter/material.dart';

/// Action de respiration appliquée à une phase.
enum BreathAction { expand, hold, contract }

/// Définition d'une phase de respiration.
class BreathPhase {
  const BreathPhase(this.seconds, this.label, this.action);
  final int seconds;
  final String label;
  final BreathAction action;

  /// Icône pertinente selon l'action de la phase.
  IconData get icon {
    switch (action) {
      case BreathAction.expand:
        return Icons.arrow_outward_rounded;
      case BreathAction.contract:
        return Icons.arrow_downward_rounded;
      case BreathAction.hold:
        return Icons.pause_rounded;
    }
  }
}

/// Breathing exercise types available in the meditation page.
///
/// Chaque technique est reconnue dans le domaine du bien-être et de la
/// psychologie physiologique. Les durées sont exprimées en secondes.
enum BreathingType {
  /// 4-7-8 breathing (Dr. Andrew Weil) : inspire 4s, retiens 7s, expire 8s.
  relaxation478(
    'Respiration 4-7-8',
    [
      BreathPhase(4, 'Inspire', BreathAction.expand),
      BreathPhase(7, 'Retiens', BreathAction.hold),
      BreathPhase(8, 'Expire', BreathAction.contract),
    ],
    'Apaisante et profonde, idéale avant le sommeil.',
    'Dr. Andrew Weil',
    Icons.nights_stay_rounded,
    Color(0xFF7E6AD8),
  ),

  /// Box breathing (Navy SEALs) : 4-4-4-4.
  carree(
    'Respiration carrée',
    [
      BreathPhase(4, 'Inspire', BreathAction.expand),
      BreathPhase(4, 'Retiens', BreathAction.hold),
      BreathPhase(4, 'Expire', BreathAction.contract),
      BreathPhase(4, 'Retiens', BreathAction.hold),
    ],
    'Équilibrante, utilisée pour la concentration.',
    'Navy SEALs',
    Icons.crop_square_rounded,
    Color(0xFFA8D5BA),
  ),

  /// Cohérence cardiaque : 5-5, respire au rythme de 6/min.
  coherence(
    'Cohérence cardiaque',
    [
      BreathPhase(5, 'Inspire', BreathAction.expand),
      BreathPhase(5, 'Expire', BreathAction.contract),
    ],
    'Équilibre le système nerveux et le rythme cardiaque.',
    '5 bpm · David Servan-Schreiber',
    Icons.favorite_rounded,
    Color(0xFFFFB5A8),
  ),

  /// Respiration diaphragmatique (ventrale) : 4-2-6.
  diaphragmatique(
    'Respiration diaphragmatique',
    [
      BreathPhase(4, 'Inspire', BreathAction.expand),
      BreathPhase(2, 'Retiens', BreathAction.hold),
      BreathPhase(6, 'Expire', BreathAction.contract),
    ],
    'Ventrale et relaxante, détend le dos et le ventre.',
    'Respiration profonde du ventre',
    Icons.air_rounded,
    Color(0xFF93B8DA),
  ),

  /// Ujjayi (respiration océanique du yoga / pranayama) : 6-6.
  ujjayi(
    'Respiration Ujjayi',
    [
      BreathPhase(6, 'Inspire', BreathAction.expand),
      BreathPhase(6, 'Expire', BreathAction.contract),
    ],
    'Respiration océanique du yoga, ancre et réchauffe.',
    'Pranayama · Yoga',
    Icons.waves_rounded,
    Color(0xFFFDD876),
  );

  const BreathingType(
    this.label,
    this.phases,
    this.description,
    this.origin,
    this.icon,
    this.color,
  );

  /// French display label.
  final String label;

  /// Phases successives (durée + libellé + action de respiration).
  final List<BreathPhase> phases;

  /// Short French description.
  final String description;

  /// Origine ou cadre de la technique (badge).
  final String origin;

  /// Icône représentative.
  final IconData icon;

  /// Couleur d'accent de la technique.
  final Color color;

  /// Durée totale d'un cycle complet en secondes.
  int get cycleDuration => phases.fold(0, (prev, p) => prev + p.seconds);
}

/// Choix de ressenti proposé à la fin d'une session.
class MoodOption {
  const MoodOption(this.icon, this.label, this.backendKey, this.color);

  final IconData icon;
  final String label;
  final String backendKey;
  final Color color;
}
