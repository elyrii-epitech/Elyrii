import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../../core/theme/app_colors.dart';

enum MoodType { verySad, sad, neutral, happy, veryHappy }

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
        return 'Très mal';
      case MoodType.sad:
        return 'Mal';
      case MoodType.neutral:
        return 'Bof';
      case MoodType.happy:
        return 'Bien';
      case MoodType.veryHappy:
        return 'Très bien';
    }
  }

  String get subtitle {
    switch (this) {
      case MoodType.verySad:
        return 'Tu te sens très mal.';
      case MoodType.sad:
        return 'Tu te sens mal.';
      case MoodType.neutral:
        return 'Ton humeur est entre les deux.';
      case MoodType.happy:
        return 'Tu te sens bien.';
      case MoodType.veryHappy:
        return 'Tu te sens très bien.';
    }
  }

  String get suggestedActionLabel {
    switch (this) {
      case MoodType.verySad:
        return '2 min de respiration apaisante';
      case MoodType.sad:
        return 'Écrire une note';
      case MoodType.neutral:
        return 'Faire une pause';
      case MoodType.happy:
        return 'Noter ce qui m\'a fait sourire';
      case MoodType.veryHappy:
        return 'Écrire une note';
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
