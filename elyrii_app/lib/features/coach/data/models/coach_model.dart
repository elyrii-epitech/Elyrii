import 'package:flutter/material.dart';

enum ActivityCategory {
  meditation,
  breathing,
  journaling,
  gratitude,
  movement,
  selfCompassion,
}

extension ActivityCategoryExtension on ActivityCategory {
  String get label {
    switch (this) {
      case ActivityCategory.meditation:
        return 'Méditation';
      case ActivityCategory.breathing:
        return 'Respiration';
      case ActivityCategory.journaling:
        return 'Écriture';
      case ActivityCategory.gratitude:
        return 'Gratitude';
      case ActivityCategory.movement:
        return 'Mouvement';
      case ActivityCategory.selfCompassion:
        return 'Auto-compassion';
    }
  }

  IconData get icon {
    switch (this) {
      case ActivityCategory.meditation:
        return Icons.self_improvement_rounded;
      case ActivityCategory.breathing:
        return Icons.air_rounded;
      case ActivityCategory.journaling:
        return Icons.edit_note_rounded;
      case ActivityCategory.gratitude:
        return Icons.favorite_rounded;
      case ActivityCategory.movement:
        return Icons.directions_walk_rounded;
      case ActivityCategory.selfCompassion:
        return Icons.spa_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ActivityCategory.meditation:
        return const Color(0xFF9D7FFE);
      case ActivityCategory.breathing:
        return const Color(0xFF93B8DA);
      case ActivityCategory.journaling:
        return const Color(0xFFFFB5A8);
      case ActivityCategory.gratitude:
        return const Color(0xFFA8D5BA);
      case ActivityCategory.movement:
        return const Color(0xFFFDD876);
      case ActivityCategory.selfCompassion:
        return const Color(0xFFD4A5E5);
    }
  }
}

class CoachActivity {
  final String id;
  final String title;
  final String description;
  final ActivityCategory category;
  final int durationMinutes;
  final IconData icon;
  final bool isRecommended;

  const CoachActivity({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.durationMinutes,
    required this.icon,
    this.isRecommended = false,
  });
}

class DailyAdvice {
  final String text;
  final String source;
  final IconData icon;

  const DailyAdvice({
    required this.text,
    required this.source,
    required this.icon,
  });
}
