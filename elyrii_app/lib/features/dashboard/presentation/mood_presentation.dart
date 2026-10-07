import 'package:flutter/material.dart';

/// Enum représentant les différents moods disponibles
enum MoodType { verySad, sad, neutral, happy, veryHappy }

/// Enum pour les types d'objectifs quotidiens
enum GoalType { journal, meditation, breathing, gratitude }

/// Extension pour obtenir les propriétés du mood
extension MoodTypeExtension on MoodType {
  IconData get icon {
    switch (this) {
      case MoodType.verySad:
        return Icons.sentiment_very_dissatisfied_rounded;
      case MoodType.sad:
        return Icons.sentiment_dissatisfied_rounded;
      case MoodType.neutral:
        return Icons.sentiment_neutral_rounded;
      case MoodType.happy:
        return Icons.sentiment_satisfied_rounded;
      case MoodType.veryHappy:
        return Icons.sentiment_very_satisfied_rounded;
    }
  }

  Color get color {
    switch (this) {
      case MoodType.verySad:
        return const Color(0xFF6B7FA3); // Ardoise apaisante
      case MoodType.sad:
        return const Color(0xFF7E94B3); // Bleu brumeux
      case MoodType.neutral:
        return const Color(0xFF8E959E); // Sauge / pierre calme
      case MoodType.happy:
        return const Color(0xFF5BA87E); // Vert clarté & sérénité
      case MoodType.veryHappy:
        return const Color(0xFFE5A038); // Ambre doré & rayonnement
    }
  }

  String get label {
    switch (this) {
      case MoodType.verySad:
        return 'Éprouvé';
      case MoodType.sad:
        return 'Vulnérable';
      case MoodType.neutral:
        return 'Paisible';
      case MoodType.happy:
        return 'Serein';
      case MoodType.veryHappy:
        return 'Rayonnant';
    }
  }

  String get subtitle {
    switch (this) {
      case MoodType.verySad:
        return 'Besoin de douceur et de repos';
      case MoodType.sad:
        return 'Une baisse d\'énergie passagère';
      case MoodType.neutral:
        return 'Calme, présent, à ton rythme';
      case MoodType.happy:
        return 'Une belle clarté d\'esprit';
      case MoodType.veryHappy:
        return 'Plein d\'élan et de gratitude';
    }
  }

  String get suggestedActionLabel {
    switch (this) {
      case MoodType.verySad:
        return '2 min de respiration apaisante';
      case MoodType.sad:
        return 'Déposer mes pensées dans le journal';
      case MoodType.neutral:
        return 'Prendre un instant de pause';
      case MoodType.happy:
        return 'Noter ce qui m\'a fait sourire';
      case MoodType.veryHappy:
        return 'Ancrer ce moment dans mon journal';
    }
  }

  IconData get suggestedActionIcon {
    switch (this) {
      case MoodType.verySad:
        return Icons.air_rounded;
      case MoodType.sad:
        return Icons.edit_note_rounded;
      case MoodType.neutral:
        return Icons.self_improvement_rounded;
      case MoodType.happy:
        return Icons.auto_awesome_rounded;
      case MoodType.veryHappy:
        return Icons.stars_rounded;
    }
  }

  String get suggestedActionRoute {
    switch (this) {
      case MoodType.verySad:
        return '/meditation';
      case MoodType.sad:
        return '/journal';
      case MoodType.neutral:
        return '/meditation';
      case MoodType.happy:
        return '/journal';
      case MoodType.veryHappy:
        return '/journal';
    }
  }
}

/// Extension pour les propriétés des objectifs
extension GoalTypeExtension on GoalType {
  String get title {
    switch (this) {
      case GoalType.journal:
        return 'Écrire dans ton journal';
      case GoalType.meditation:
        return '5 minutes de méditation';
      case GoalType.breathing:
        return 'Exercice de respiration';
      case GoalType.gratitude:
        return 'Noter 3 gratitudes';
    }
  }

  IconData get icon {
    switch (this) {
      case GoalType.journal:
        return Icons.edit_note_rounded;
      case GoalType.meditation:
        return Icons.self_improvement_rounded;
      case GoalType.breathing:
        return Icons.air_rounded;
      case GoalType.gratitude:
        return Icons.favorite_rounded;
    }
  }

  String get completedMessage {
    switch (this) {
      case GoalType.journal:
        return 'Bravo ! Tu as pris le temps d\'écrire';
      case GoalType.meditation:
        return 'Magnifique ! Ton esprit te remercie';
      case GoalType.breathing:
        return 'Super ! Tu respires la sérénité';
      case GoalType.gratitude:
        return 'Génial ! La gratitude illumine ta journée';
    }
  }
}
