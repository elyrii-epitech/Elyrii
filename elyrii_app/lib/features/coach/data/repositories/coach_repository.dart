import 'package:flutter/material.dart';
import '../models/coach_model.dart';

class CoachRepository {
  static const List<DailyAdvice> _advices = [
    DailyAdvice(
      text: 'La régularité est plus importante que la durée. Mieux vaut 3 minutes chaque jour que 30 minutes une fois par semaine.',
      source: 'Recherche en neuroscience',
      icon: Icons.yard_rounded,
    ),
    DailyAdvice(
      text: 'Nommer ce que tu ressens réduit son intensité. Essaye : "Je remarque que je me sens..."',
      source: 'Thérapie cognitive-comportementale',
      icon: Icons.psychology_rounded,
    ),
    DailyAdvice(
      text: 'Ton corps et ton esprit sont liés. Une marche de 10 minutes peut changer ta journée.',
      source: 'Psychologie positive',
      icon: Icons.directions_walk_rounded,
    ),
    DailyAdvice(
      text: "Il n'y a pas de « bonne » façon de méditer. Si tu es présent, tu réussis.",
      source: 'Pleine conscience (Mindfulness)',
      icon: Icons.self_improvement_rounded,
    ),
    DailyAdvice(
      text: "Écrire 3 choses dont tu es reconnaissant(e) chaque soir améliore significativement ton bien-être.",
      source: 'Étude Robert Emmons',
      icon: Icons.auto_awesome_rounded,
    ),
    DailyAdvice(
      text: 'Respirer profondément 4 secondes, retenir 7 secondes, expirer 8 secondes active ton système nerveux parasympathique.',
      source: 'Technique 4-7-8 du Dr. Andrew Weil',
      icon: Icons.air_rounded,
    ),
    DailyAdvice(
      text: "T'accorder 5 minutes de pause n'est pas de la paresse, c'est de l'hygiène mentale.",
      source: 'Psychologie du burn-out',
      icon: Icons.coffee_rounded,
    ),
    DailyAdvice(
      text: 'Les émotions difficiles sont comme les vagues : elles montent, puis elles redescendent toujours.',
      source: 'Thérapie d\'acceptation (ACT)',
      icon: Icons.water_rounded,
    ),
    DailyAdvice(
      text: 'Parler à quelqu\'un — même un chatbot — de ce que tu ressens aide à structurer tes pensées.',
      source: 'Journaling thérapeutique',
      icon: Icons.record_voice_over_rounded,
    ),
    DailyAdvice(
      text: "Chaque nuit, ton cerveau traite tes émotions. Un bon sommeil est le premier pas vers le bien-être.",
      source: 'Neuroscience du sommeil',
      icon: Icons.bedtime_rounded,
    ),
    DailyAdvice(
      text: "Soyez bienveillant envers vous-même. Traitez-vous comme vous traiteriez un bon ami.",
      source: 'Auto-compassion (Kristin Neff)',
      icon: Icons.volunteer_activism_rounded,
    ),
    DailyAdvice(
      text: "L'anxiété vit dans le futur, la tristesse dans le passé. La paix se trouve dans le présent.",
      source: 'Sagesse contemplative',
      icon: Icons.wb_twilight_rounded,
    ),
  ];

  static const List<CoachActivity> _activities = [
    CoachActivity(
      id: 'body-scan-5',
      title: 'Scan corporel express',
      description: 'Parcours ton corps de la tête aux pieds et relâche chaque tension.',
      category: ActivityCategory.meditation,
      durationMinutes: 5,
      icon: Icons.accessibility_new_rounded,
      isRecommended: true,
    ),
    CoachActivity(
      id: 'gratitude-soir',
      title: '3 gratitudes du soir',
      description: 'Note 3 choses positives de ta journée, même les plus petites.',
      category: ActivityCategory.gratitude,
      durationMinutes: 3,
      icon: Icons.favorite_rounded,
      isRecommended: true,
    ),
    CoachActivity(
      id: 'respiration-coherence',
      title: 'Cohérence cardiaque',
      description: '5 secondes inspire, 5 secondes expire. Pendant 5 minutes.',
      category: ActivityCategory.breathing,
      durationMinutes: 5,
      icon: Icons.waves_rounded,
    ),
    CoachActivity(
      id: 'journal-libre',
      title: 'Écriture libre',
      description: 'Laisse tes pensées couler sur papier, sans filtre ni jugement.',
      category: ActivityCategory.journaling,
      durationMinutes: 10,
      icon: Icons.edit_note_rounded,
    ),
    CoachActivity(
      id: 'marche-mindful',
      title: 'Marche en pleine conscience',
      description: 'Marche lentement en prêtant attention à chaque pas et sensation.',
      category: ActivityCategory.movement,
      durationMinutes: 10,
      icon: Icons.nature_people_rounded,
    ),
    CoachActivity(
      id: 'auto-compassion',
      title: 'Lettre de compassion',
      description: 'Écris-toi une lettre comme si tu écrivais à ton meilleur ami.',
      category: ActivityCategory.selfCompassion,
      durationMinutes: 8,
      icon: Icons.mail_outline_rounded,
      isRecommended: true,
    ),
    CoachActivity(
      id: 'muscle-relaxation',
      title: 'Relaxation musculaire progressive',
      description: 'Contracte puis relâche chaque groupe musculaire, un par un.',
      category: ActivityCategory.meditation,
      durationMinutes: 7,
      icon: Icons.spa_rounded,
    ),
    CoachActivity(
      id: 'respiration-478',
      title: 'Respiration apaisante 4-7-8',
      description: 'La technique recommandée par les experts pour calmer l\'anxiété.',
      category: ActivityCategory.breathing,
      durationMinutes: 5,
      icon: Icons.self_improvement_rounded,
    ),
  ];

  DailyAdvice getAdviceForToday() {
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    return _advices[dayOfYear % _advices.length];
  }

  List<CoachActivity> getRecommendedActivities() {
    return _activities.where((a) => a.isRecommended).toList();
  }

  List<CoachActivity> getAllActivities() {
    return _activities;
  }

  List<CoachActivity> getActivitiesByCategory(ActivityCategory category) {
    return _activities.where((a) => a.category == category).toList();
  }
}
