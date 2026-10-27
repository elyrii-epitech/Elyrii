import '../domain/journey.dart';

final List<JourneyPath> journeyCatalog = List.unmodifiable([
  JourneyPath(
    pathId: 'connection-small-steps',
    contentVersion: 2,
    title: 'Garder le contact',
    description: 'Préparer un message et choisir comment reprendre contact.',
    topic: JourneyTopic.connection,
    steps: [
      const JourneyStep(
        stepId: 'connection-prepare',
        title: 'Penser à une personne',
        instructions: 'Choisis une personne à qui tu aimerais donner des nouvelles. Note quelques idées dans le Journal si cela t’aide.',
        durationMinutes: 2,
        action: JourneyJournalAction(prompt: 'Une personne à qui je pense'),
      ),
      const JourneyStep(
        stepId: 'connection-message',
        title: 'Préparer quelques mots',
        instructions: 'Prépare un message pour une personne de ton choix. L’envoi est facultatif.',
        durationMinutes: 3,
        action: JourneyNoAction(),
      ),
      const JourneyStep(
        stepId: 'connection-gratitude',
        title: 'Remarquer un petit geste',
        instructions: 'Note un geste qui a compté pour toi. Contacter la personne est facultatif.',
        durationMinutes: 2,
        action: JourneyJournalAction(
          prompt: 'Un petit geste qui a compté pour moi',
        ),
      ),
    ],
  ),
  JourneyPath(
    pathId: 'calm-at-your-pace',
    contentVersion: 2,
    title: 'Faire une pause',
    description: 'Faire un exercice de respiration, puis écrire quelques mots.',
    topic: JourneyTopic.calm,
    steps: const [
      JourneyStep(
        stepId: 'calm-natural-breath',
        title: 'Observer le souffle',
        instructions: 'Assieds-toi comme tu es à l’aise. Observe ton souffle comme il vient, sans chercher à le changer. Tu peux garder les yeux ouverts, arrêter à tout moment ou simplement remarquer tes appuis si le souffle te met mal à l’aise.',
        durationMinutes: 3,
        action: JourneyMeditationAction(
          programId: 'mindful-breathing',
          durationMinutes: 3,
        ),
      ),
      JourneyStep(
        stepId: 'calm-free-writing',
        title: 'Écriture libre',
        instructions: 'Écris ce qui te vient dans le Journal.',
        durationMinutes: 5,
        action: JourneyJournalAction(prompt: 'Écriture libre'),
      ),
    ],
  ),
  JourneyPath(
    pathId: 'sleep-evening-pause',
    contentVersion: 2,
    title: 'Une pause avant la nuit',
    description:
        'Revenir sur ta journée et faire un scan corporel avant de te coucher.',
    topic: JourneyTopic.sleep,
    steps: const [
      JourneyStep(
        stepId: 'sleep-gratitudes',
        title: 'Les petites choses du jour',
        instructions: 'Repense à un bon moment de ta journée. Note-le dans le Journal ou garde-le en tête.',
        durationMinutes: 3,
        action: JourneyJournalAction(prompt: 'Un bon moment de la journée'),
      ),
      JourneyStep(
        stepId: 'sleep-body-scan',
        title: 'Parcourir les sensations',
        instructions: 'Assieds-toi ou allonge-toi confortablement. Porte ton attention sur les sensations du visage jusqu’aux pieds, sans chercher à les changer. Tu peux rester sur une zone confortable, garder les yeux ouverts ou arrêter quand tu le souhaites.',
        durationMinutes: 5,
        action: JourneyMeditationAction(
          programId: 'body-scan',
          durationMinutes: 5,
        ),
      ),
    ],
  ),
]);

/// Refreshes only editorial text for a known, structurally identical v1 path.
/// Enrollment identity, progress, timestamps, and actions remain unchanged.
JourneyPath refreshedJourneyCopy(JourneyPath stored) {
  if (stored.contentVersion != 1) return stored;
  final current = journeyCatalog
      .where((path) => path.pathId == stored.pathId && path.contentVersion == 2)
      .firstOrNull;
  if (current == null ||
      current.topic != stored.topic ||
      current.steps.length != stored.steps.length) {
    return stored;
  }
  for (var i = 0; i < current.steps.length; i++) {
    final oldStep = stored.steps[i];
    final newStep = current.steps[i];
    final sameAction = switch ((oldStep.action, newStep.action)) {
      (JourneyNoAction(), JourneyNoAction()) => true,
      (JourneyJournalAction(), JourneyJournalAction()) => true,
      (
        JourneyMeditationAction(
          programId: final oldId,
          durationMinutes: final oldDuration,
        ),
        JourneyMeditationAction(
          programId: final newId,
          durationMinutes: final newDuration,
        ),
      ) =>
        oldId == newId && oldDuration == newDuration,
      _ => false,
    };
    if (oldStep.stepId != newStep.stepId ||
        oldStep.durationMinutes != newStep.durationMinutes ||
        !sameAction) {
      return stored;
    }
  }
  return current;
}
