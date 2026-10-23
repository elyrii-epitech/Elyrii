import '../../dashboard/domain/accueil_content.dart';
import '../domain/journey.dart';

final List<JourneyPath> journeyCatalog = List.unmodifiable([
  JourneyPath(
    pathId: 'connection-small-steps',
    contentVersion: 1,
    title: 'Un pas vers les autres',
    description: 'Préparer un petit geste de lien, sans obligation de contacter quelqu’un ni d’obtenir une réponse.',
    topic: JourneyTopic.connection,
    steps: [
      const JourneyStep(
        stepId: 'connection-prepare',
        title: 'Penser à une personne',
        instructions: 'Pense à quelqu’un qui compte pour toi. Tu peux simplement préparer quelques mots dans ta tête ou dans le Journal, sans les envoyer.',
        durationMinutes: 2,
        action: JourneyJournalAction(prompt: 'Une personne à qui je pense'),
      ),
      JourneyStep(
        stepId: 'connection-message',
        title: 'Préparer quelques mots',
        instructions:
            '${socialIdeas.first}\n\nTu peux préparer « $contactShareText » sans l’envoyer. La préparation suffit pour cette étape. Aucun contact ni aucune réponse ne sont nécessaires.',
        durationMinutes: 3,
        action: const JourneyNoAction(),
      ),
      JourneyStep(
        stepId: 'connection-gratitude',
        title: 'Remarquer un petit geste',
        instructions:
            '${socialIdeas[1]}\n\nSi tu préfères, note seulement ce geste pour toi. Tu n’as pas besoin de contacter cette personne pour terminer l’étape.',
        durationMinutes: 2,
        action: const JourneyJournalAction(
          prompt: 'Un petit geste qui a compté pour moi',
        ),
      ),
    ],
  ),
  JourneyPath(
    pathId: 'calm-at-your-pace',
    contentVersion: 1,
    title: 'Une pause à ton rythme',
    description: 'Observer ton souffle puis déposer quelques pensées, sans chercher à obtenir un résultat particulier.',
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
        instructions: 'Laisse tes pensées couler sur papier, sans filtre ni jugement. Quelques mots suffisent et tu peux t’arrêter quand tu le souhaites.',
        durationMinutes: 5,
        action: JourneyJournalAction(prompt: 'Écriture libre'),
      ),
    ],
  ),
  JourneyPath(
    pathId: 'sleep-evening-pause',
    contentVersion: 1,
    title: 'Une pause avant la nuit',
    description: 'Revenir sur sa journée et observer les sensations du corps, sans objectif de sommeil à atteindre.',
    topic: JourneyTopic.sleep,
    steps: const [
      JourneyStep(
        stepId: 'sleep-gratitudes',
        title: 'Les petites choses du jour',
        instructions: 'Note trois choses positives de ta journée, même les plus petites. Une seule suffit si c’est ce qui te vient. Tu peux aussi simplement y penser sans écrire.',
        durationMinutes: 3,
        action: JourneyJournalAction(prompt: 'Trois gratitudes du soir'),
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
