import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../../core/theme/app_colors.dart';

/// Enum représentant les différents moods disponibles
enum MoodType { verySad, sad, neutral, happy, veryHappy }

/// Extension pour obtenir les propriétés du mood
extension MoodTypeExtension on MoodType {
  IconData get icon {
    switch (this) {
      case MoodType.verySad:
        return Symbols.sentiment_stressed_rounded;
      case MoodType.sad:
        return Symbols.sentiment_sad_rounded;
      case MoodType.neutral:
        return Symbols.sentiment_calm_rounded;
      case MoodType.happy:
        return Symbols.sentiment_satisfied_rounded;
      case MoodType.veryHappy:
        return Symbols.sentiment_excited_rounded;
    }
  }

  /// Couleur du mood selon le thème : rose, orange, teal, vert, jaune v2.
  Color colorFor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    switch (this) {
      case MoodType.verySad:
        return AppColors.pink(isDark);
      case MoodType.sad:
        return AppColors.orange(isDark);
      case MoodType.neutral:
        return AppColors.teal(isDark);
      case MoodType.happy:
        return AppColors.green(isDark);
      case MoodType.veryHappy:
        return AppColors.yellow(isDark);
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
