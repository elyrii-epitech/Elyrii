import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

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

/// Besoin immédiat exprimé par l'utilisateur : c'est la clé de routage du
/// coach. Chaque activité est étiquetée avec les besoins qu'elle sert.
enum CoachNeed { calm, sleep, clearMind, selfCare }

extension CoachNeedExtension on CoachNeed {
  String get label {
    switch (this) {
      case CoachNeed.calm:
        return 'Se calmer';
      case CoachNeed.sleep:
        return 'Mieux dormir';
      case CoachNeed.clearMind:
        return 'Vider ma tête';
      case CoachNeed.selfCare:
        return 'Être doux·ce';
    }
  }

  IconData get icon {
    switch (this) {
      case CoachNeed.calm:
        return Icons.spa_rounded;
      case CoachNeed.sleep:
        return Icons.bedtime_rounded;
      case CoachNeed.clearMind:
        return Icons.bubble_chart_rounded;
      case CoachNeed.selfCare:
        return Icons.favorite_border_rounded;
    }
  }

  Color get color {
    switch (this) {
      case CoachNeed.calm:
        return AppColors.primary;
      case CoachNeed.sleep:
        return AppColors.info;
      case CoachNeed.clearMind:
        return AppColors.accent;
      case CoachNeed.selfCare:
        return AppColors.secondary;
    }
  }

  /// Titre de la section recommandée quand ce besoin est sélectionné.
  String get sectionTitle {
    switch (this) {
      case CoachNeed.calm:
        return 'Pour t\'apaiser';
      case CoachNeed.sleep:
        return 'Pour t\'endormir';
      case CoachNeed.clearMind:
        return 'Pour vider ta tête';
      case CoachNeed.selfCare:
        return 'Pour prendre soin de toi';
    }
  }

  /// Message que Velours affiche dans sa bulle quand le besoin est choisi.
  String get bubbleMessage {
    switch (this) {
      case CoachNeed.calm:
        return 'On va poser les choses, tout doucement.';
      case CoachNeed.sleep:
        return 'Préparons le terrain d\'un beau sommeil.';
      case CoachNeed.clearMind:
        return 'Libérons un peu d\'espace dans ta tête.';
      case CoachNeed.selfCare:
        return 'Tu as le droit d\'être doux·ce avec toi.';
    }
  }
}

/// Ce qui se passe concrètement quand l'utilisateur choisit l'activité :
/// une séance de respiration native, une entrée de journal guidée, ou une
/// guidance personnalisée générée par l'IA du coach.
enum CoachActivityKind { breathing, journal, guidance }

class CoachActivity {
  final String id;
  final String title;
  final String description;
  final ActivityCategory category;
  final int durationMinutes;
  final IconData icon;
  final bool isRecommended;

  /// Expérience lancée au tap : séance native, journal guidé ou guidance IA.
  final CoachActivityKind kind;

  /// Prompt pré-remplissant le journal quand [kind] est `journal`.
  final String? journalPrompt;

  /// Identifiant de technique respiratoire quand [kind] est `breathing`
  /// (résolu par le lanceur côté présentation).
  final String? breathingTechnique;

  /// Besoins servis par cette activité, utilisés par le routage du coach.
  final List<CoachNeed> needs;

  const CoachActivity({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.durationMinutes,
    required this.icon,
    this.isRecommended = false,
    this.kind = CoachActivityKind.guidance,
    this.journalPrompt,
    this.breathingTechnique,
    this.needs = const [],
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

class CoachSession {
  final String id;
  final String prompt;
  final String response;
  final Map<String, dynamic> context;
  final DateTime createdAt;

  const CoachSession({
    required this.id,
    required this.prompt,
    required this.response,
    required this.context,
    required this.createdAt,
  });

  factory CoachSession.fromJson(Map<String, dynamic> json) {
    return CoachSession(
      id: json['id'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      response: json['response'] as String? ?? '',
      context: Map<String, dynamic>.from(
        json['context'] as Map? ?? const <String, dynamic>{},
      ),
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
