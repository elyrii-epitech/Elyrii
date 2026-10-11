import '../../../../core/network/json_response.dart';

import 'package:flutter/material.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/coach_model.dart';

class CoachRepository {
  final ApiClient _client;

  CoachRepository({required this._client});

  static const List<DailyAdvice> _advices = [
    DailyAdvice(
      text: 'Prends un instant pour remarquer ce qui t’entoure : un son, une couleur ou le contact de tes pieds au sol.',
      source: 'OMS — Faire ce qui compte en période de stress (2020)',
      sourceUrl: 'https://www.who.int/publications/i/item/9789240003927',
      icon: Icons.yard_rounded,
    ),
    DailyAdvice(
      text: 'Tu peux nommer ce que tu ressens sans te juger. Si cela devient trop difficile, cherche le soutien d’une personne de confiance ou d’un professionnel.',
      source: 'OMS — Faire ce qui compte en période de stress (2020)',
      sourceUrl: 'https://www.who.int/publications/i/item/9789240003927',
      icon: Icons.psychology_rounded,
    ),
    DailyAdvice(
      text: 'Pour une pause, essaie une respiration douce et confortable, sans forcer ni retenir ton souffle. Arrête si tu ressens un malaise.',
      source: 'NHS — Breathing exercises for stress',
      sourceUrl: 'https://www.nhs.uk/mental-health/self-help/guides-tools-and-activities/breathing-exercises-for-stress/',
      icon: Icons.air_rounded,
    ),
    DailyAdvice(
      text: 'La méditation convient à certaines personnes, avec des effets variables. Tu peux choisir une autre activité si cette pratique te met mal à l’aise.',
      source: 'NCCIH — Meditation and mindfulness',
      sourceUrl: 'https://www.nccih.nih.gov/health/meditation-and-mindfulness-what-you-need-to-know',
      icon: Icons.self_improvement_rounded,
    ),
    DailyAdvice(
      text: 'Choisis une petite action qui compte pour toi aujourd’hui, à ton rythme. Ces exercices de bien-être ne remplacent pas une prise en charge médicale.',
      source: 'OMS — Faire ce qui compte en période de stress (2020)',
      sourceUrl: 'https://www.who.int/publications/i/item/9789240003927',
      icon: Icons.volunteer_activism_rounded,
    ),
  ];

  static const List<CoachActivity> _activities = [
    CoachActivity(
      id: 'body-scan-5',
      title: 'Scan corporel express',
      description:
          'Parcours ton corps de la tête aux pieds et relâche chaque tension.',
      category: ActivityCategory.meditation,
      durationMinutes: 5,
      icon: Icons.accessibility_new_rounded,
      isRecommended: true,
      kind: CoachActivityKind.guidance,
      needs: [CoachNeed.calm],
    ),
    CoachActivity(
      id: 'gratitude-soir',
      title: '3 gratitudes du soir',
      description:
          'Note 3 choses positives de ta journée, même les plus petites.',
      category: ActivityCategory.gratitude,
      durationMinutes: 3,
      icon: Icons.favorite_rounded,
      isRecommended: true,
      kind: CoachActivityKind.journal,
      journalPrompt: 'Trois gratitudes du soir',
      needs: [CoachNeed.sleep, CoachNeed.selfCare],
    ),
    CoachActivity(
      id: 'respiration-coherence',
      title: 'Cohérence cardiaque',
      description: '5 secondes inspire, 5 secondes expire. Pendant 5 minutes.',
      category: ActivityCategory.breathing,
      durationMinutes: 5,
      icon: Icons.waves_rounded,
      isRecommended: true,
      kind: CoachActivityKind.breathing,
      breathingTechnique: 'coherence',
      needs: [CoachNeed.calm, CoachNeed.clearMind],
    ),
    CoachActivity(
      id: 'journal-libre',
      title: 'Écriture libre',
      description:
          'Laisse tes pensées couler sur papier, sans filtre ni jugement.',
      category: ActivityCategory.journaling,
      durationMinutes: 10,
      icon: Icons.edit_note_rounded,
      kind: CoachActivityKind.journal,
      journalPrompt: 'Écriture libre',
      needs: [CoachNeed.clearMind],
    ),
    CoachActivity(
      id: 'marche-mindful',
      title: 'Marche en pleine conscience',
      description:
          'Marche lentement en prêtant attention à chaque pas et sensation.',
      category: ActivityCategory.movement,
      durationMinutes: 10,
      icon: Icons.nature_people_rounded,
      kind: CoachActivityKind.guidance,
      needs: [CoachNeed.clearMind, CoachNeed.selfCare],
    ),
    CoachActivity(
      id: 'auto-compassion',
      title: 'Lettre de compassion',
      description:
          'Écris-toi une lettre comme si tu écrivais à ton meilleur ami.',
      category: ActivityCategory.selfCompassion,
      durationMinutes: 8,
      icon: Icons.mail_outline_rounded,
      kind: CoachActivityKind.journal,
      journalPrompt: 'Lettre de compassion à moi-même',
      needs: [CoachNeed.selfCare],
    ),
    CoachActivity(
      id: 'muscle-relaxation',
      title: 'Relaxation musculaire progressive',
      description:
          'Contracte puis relâche chaque groupe musculaire, un par un.',
      category: ActivityCategory.meditation,
      durationMinutes: 7,
      icon: Icons.spa_rounded,
      kind: CoachActivityKind.guidance,
      needs: [CoachNeed.calm, CoachNeed.sleep],
    ),
    CoachActivity(
      id: 'respiration-478',
      title: 'Respiration apaisante 4-7-8',
      description: 'Une respiration guidée optionnelle. Choisis un rythme confortable et arrête en cas de malaise.',
      category: ActivityCategory.breathing,
      durationMinutes: 5,
      icon: Icons.self_improvement_rounded,
      kind: CoachActivityKind.breathing,
      breathingTechnique: 'relaxation478',
      needs: [CoachNeed.calm, CoachNeed.sleep],
    ),
  ];

  DailyAdvice getAdviceForToday() {
    final dayOfYear = DateTime.now()
        .difference(DateTime(DateTime.now().year, 1, 1))
        .inDays;
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

  /// Activités servant un besoin immédiat exprimé par l'utilisateur,
  /// dans l'ordre du catalogue.
  List<CoachActivity> getActivitiesForNeed(CoachNeed need) {
    return _activities.where((a) => a.needs.contains(need)).toList();
  }

  /// Guidance de substitution, en attendant que le contenu IA soit défini
  /// côté backend. Structure de séance réelle et honnête : elle reste
  /// utilisable telle quelle et sera remplacée par la réponse du coach.
  String placeholderGuidanceFor(CoachActivity activity) {
    final byId = {
      'body-scan-5':
          'Installe-toi confortablement, yeux fermés.\n\n'
          '1. Trois grandes respirations pour poser le cadre.\n'
          '2. Porte ton attention sur le sommet du crâne, puis descends '
          'lentement : visage, épaules, bras, dos, jambes, pieds.\n'
          '3. À chaque zone, remarque la tension — sans juger — et laisse-la '
          's\'alléger à l\'expiration.\n\n'
          'Si ta tête s\'égare, c\'est normal : reviens simplement au dernier '
          'endroit visité.',
      'marche-mindful':
          'Sors sans destination précise.\n\n'
          '1. Les trente premières secondes, ralentis franchement ton pas.\n'
          '2. Sens le contact de chaque pied : talon, plante, orteils.\n'
          '3. Ouvre l\'ouïe : trois sons, proches ou lointains.\n'
          '4. Termine par une pause et nomme ce que tu ressens.\n\n'
          'L\'objectif n\'est pas d\'arriver, c\'est d\'être là.',
      'muscle-relaxation':
          'Allonge-toi ou assieds-toi bien calé.\n\n'
          '1. Mains : serre les poings 5 secondes, relâche 10 secondes.\n'
          '2. Épaules : monte-les vers les oreilles, relâche.\n'
          '3. Visage : grimace complète, puis détends chaque muscle.\n'
          '4. Jambes puis pieds : même cycle serre-relâche.\n\n'
          'À chaque relâchement, l\'expiration s\'allonge un peu plus.',
    };
    return byId[activity.id] ??
        'Séance « ${activity.title} » — ${activity.durationMinutes} minutes.\n\n'
            '1. Deux minutes pour installer le cadre et respirer.\n'
            '2. Le cœur de la pratique, à ton rythme.\n'
            '3. Une minute pour noter ce que tu ressens.\n\n'
            'Le contenu personnalisé de cette séance arrive bientôt.';
  }

  Future<List<CoachSession>> getSessions({int limit = 20}) async {
    final response = await _client.get(
      ApiConfig.coachSessionsUrl,
      queryParams: {'limit': '$limit'},
    );
    return decodeListResponse(response, CoachSession.fromJson);
  }

  Future<CoachSession> createSession({
    required String prompt,
    Map<String, dynamic>? context,
  }) async {
    final response = await _client.post(
      ApiConfig.coachSessionsUrl,
      body: {'prompt': prompt, 'context': ?context},
    );
    return decodeResponse(response, CoachSession.fromJson);
  }
}
