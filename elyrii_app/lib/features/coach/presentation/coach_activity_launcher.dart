import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/mascot_animations.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/glass/liquid_glass_kit.dart';
import '../../../../routes/app_routes.dart';
import '../../journal/presentation/providers/journal_provider.dart';
import '../../journal/presentation/widgets/journal_editor_sheet.dart';
import '../../mascot/presentation/providers/mascot_provider.dart';
import '../../meditation/data/repositories/meditation_repository.dart';
import '../../meditation/domain/models/breath_phase.dart';
import '../../meditation/presentation/controllers/meditation_controller.dart';
import '../data/models/coach_model.dart';
import 'providers/coach_provider.dart';
import 'widgets/guidance_sheet.dart';

/// Résolution des identifiants de technique respiratoire référencés par le
/// catalogue du coach vers les types natifs de la méditation.
BreathingType? _resolveBreathingTechnique(String? technique) {
  return switch (technique) {
    'coherence' => BreathingType.coherence,
    'relaxation478' => BreathingType.relaxation478,
    'carree' => BreathingType.carree,
    'diaphragmatique' => BreathingType.diaphragmatique,
    'ujjayi' => BreathingType.ujjayi,
    _ => null,
  };
}

/// Lance l'expérience réelle d'une activité du coach.
///
/// Chaque tap fait quelque chose de vrai :
/// - respiration → séance immersive native, pré-réglée sur la technique et
///   la durée de l'activité ;
/// - écriture → feuille de journal pré-remplie avec le prompt guidé ;
/// - guidance → séance personnalisée générée par l'IA du coach, présentée
///   dans une feuille dédiée.
Future<void> launchCoachActivity(
  BuildContext context,
  CoachActivity activity,
) async {
  ElyriiHaptics.light();

  switch (activity.kind) {
    case CoachActivityKind.breathing:
      await _launchBreathing(context, activity);
    case CoachActivityKind.journal:
      _launchJournal(context, activity);
    case CoachActivityKind.guidance:
      await _launchGuidance(context, activity);
  }
}

Future<void> _launchBreathing(
  BuildContext context,
  CoachActivity activity,
) async {
  final technique = _resolveBreathingTechnique(activity.breathingTechnique);
  if (technique == null) {
    // Technique inconnue : repli honnête sur la guidance IA plutôt qu'un
    // écran cassé.
    await _launchGuidance(context, activity);
    return;
  }

  final controller = MeditationController(
    repository: MeditationRepository(client: context.read<ApiClient>()),
  )..setBreathingType(technique);
  controller.setDuration(activity.durationMinutes);

  context.read<MascotProvider>().react(MascotAnimations.invite);

  // `startSession` passe en `running` synchronusement (l'inscription backend
  // continue en arrière-plan) : la séance est déjà vivante quand la route
  // immersive apparaît.
  unawaited(controller.startSession());
  await context.push(AppRoutes.meditationSession, extra: controller);

  // Le coach est propriétaire du cycle de vie du contrôleur qu'il crée.
  if (context.mounted) controller.dispose();
}

void _launchJournal(BuildContext context, CoachActivity activity) {
  context.read<MascotProvider>().react(MascotAnimations.attentive);

  showLiquidGlassSheet(
    context: context,
    initialChildSize: 0.92,
    maxChildSize: 0.92,
    minChildSize: 0.5,
    child: JournalEditorSheet(
      provider: context.read<JournalProvider>(),
      initialPrompt: activity.journalPrompt,
    ),
  );
}

Future<bool> _requestGuidance(
  BuildContext context,
  CoachProvider coachProvider,
  CoachActivity activity,
) async {
  final success = await coachProvider.requestGuidanceForActivity(activity);
  if (!context.mounted) return success;
  if (success) {
    context.read<MascotProvider>().react(MascotAnimations.acknowledge);
    coachProvider.setMascotMessage('Voilà. À toi de jouer, je reste là.');
  }
  return success;
}
Future<void> _launchGuidance(
  BuildContext context,
  CoachActivity activity,
) async {
  final coachProvider = context.read<CoachProvider>();
  // La feuille s'ouvre immédiatement : son état « préparation » vit le
  // temps de la requête, puis laisse place à la réponse.
  unawaited(_requestGuidance(context, coachProvider, activity));

  await showLiquidGlassSheet<bool>(
    context: context,
    initialChildSize: 0.55,
    maxChildSize: 0.85,
    minChildSize: 0.3,
    child: GuidanceSheet(activity: activity),
  );
}
