# Méditation : durées libres et catalogue

La page conserve son titre et son bouton de références dans l’en-tête. La durée se règle à la minute, de **1 à 180 minutes**. Les raccourcis sont 2, 5, 10, 15, 20 et 30 minutes ; une feuille permet de saisir toute autre durée. Le clavier et le texte agrandi sont pris en compte.

Le catalogue contient 12 exercices, filtrables par respiration, présence, corps et bienveillance. Le choix d’un exercice conserve la durée choisie. Le bouton de lancement reste visible pendant le défilement.

| Pratique | Guidage |
| --- | --- |
| Découverte | Souffle 3–3, sans rétention |
| Équilibre | Souffle 5–5, six respirations par minute |
| Ralentir | Expiration prolongée, repère 4–6 |
| Ventre détendu | Attention au ventre, repère 4–6 sans rétention |
| Focus | Respiration carrée 4–4–4–4 |
| Pause 4–7–8 | Jusqu’à quatre cycles, puis souffle naturel jusqu’à la fin du temps choisi |
| Souffle océan | Inspiration du yoga, repère 6–6 |
| Souffle conscient | Consignes écrites, respiration naturelle |
| Scan corporel | Consignes écrites, déplacement de l’attention dans le corps |
| Écoute des sons | Consignes écrites, attention au présent |
| Bienveillance | Consignes écrites, souhaits bienveillants |
| Auto-compassion | Consignes écrites, soutien envers soi |

Les cinq pratiques écrites ont des étapes pondérées. Le contrôleur répartit chaque étape sur une proportion de la durée totale, en incluant l’installation et le retour final. Il n’impose pas de cadence respiratoire à ces pratiques. La pause fige le temps et l’étape ; la reprise continue au même endroit. Il n’y a pas de piste audio enregistrée.

Les titres des séances restent entre les commandes d’interruption et de pause. Les longues consignes peuvent défiler. Le bilan distingue les cycles respiratoires des étapes d’une pratique guidée.

## Références et statut de la revue

Les textes français sont des scripts originaux d’Elyrii. Les rythmes numériques et la distribution des étapes sont des adaptations pour l’application, pas des protocoles cliniques attribués aux organismes cités.

| Référence proposée | Rôle |
| --- | --- |
| [NHS : exercices de respiration](https://www.nhs.uk/mental-health/self-help/guides-tools-and-activities/breathing-exercises-for-stress/) | Respiration douce et confortable ; les repères 3–3/5–5 sont des adaptations |
| [VA Whole Health : respiration diaphragmatique](https://www.va.gov/WHOLEHEALTHLIBRARY/tools/diaphragmatic-breathing.asp) | Attention au ventre et respiration diaphragmatique ; 4–6 est un repère de l’app |
| [Cleveland Clinic : respiration carrée](https://health.clevelandclinic.org/box-breathing-benefits) | Référence spécifique prévue pour la respiration carrée |
| [Dr Andrew Weil : exercices de respiration](https://www.drweil.com/health-wellness/body-mind-spirit/stress-anxiety/breathing-three-exercises/) | Méthode 4–7–8 ; limite de quatre cycles avant le retour au souffle naturel |
| [UC Berkeley : mindful breathing](https://ggia.berkeley.edu/practice/mindful_breathing) | Pratique d’attention au souffle naturel |
| [UC Berkeley : body scan](https://ggia.berkeley.edu/practice/body_scan_meditation) | Balayage de l’attention dans le corps |
| [UC Berkeley : loving-kindness](https://ggia.berkeley.edu/practice/loving_kindness_meditation) | Souhaits bienveillants |
| [UC Berkeley : self-compassion break](https://ggia.berkeley.edu/practice/self_compassion_break) | Reconnaissance de la difficulté, humanité commune et soutien envers soi |
| [NHS : mindfulness](https://www.nhs.uk/mental-health/self-help/tips-and-support/mindfulness/) | Référence générale pour l’attention au présent et aux sensations |
| [NCCIH : méditation et pleine conscience](https://www.nccih.nih.gov/health/meditation-and-mindfulness-effectiveness-and-safety) | Contexte général ; aucune promesse de traitement dans les descriptions |
| [NCCIH : yoga](https://www.nccih.nih.gov/health/yoga-what-you-need-to-know) | Contexte général du yoga ; ne valide pas le rythme 6–6 ni une instruction Ujjayi spécifique |

**Vérification en ligne incomplète le 3 octobre 2026.** La politique réseau de l’environnement a refusé en HTTP 403 les destinations professionnelles testées. Ces liens sont des références identifiées à partir de connaissances existantes ; leur contenu actuel et leur disponibilité n’ont pas été contrôlés en direct. Les captures ne constituent pas une validation éditoriale par ces organismes ou par un professionnel. Cette vérification reste à faire après autorisation des domaines.

## API et compatibilité

`POST /meditation/sessions/start` reconnaît les 12 identifiants natifs du catalogue et accepte une durée entière de 1 à 180 minutes. `durationMinutes` dans le catalogue serveur est désormais une suggestion. Les identifiants historiques `breathing-5m`, `body-scan-10m` et `grounding-15m` restent acceptés.

Le client envoie l’identifiant de l’exercice et la durée choisie. La fin de séance est enregistrée même sans sélection d’un ressenti. Une sélection ultérieure met à jour ce ressenti. Une réponse de création arrivée après une interruption est annulée ; arrivée après la fin, elle est complétée. Une synchronisation échouée est signalée dans le bilan.

Les modifications serveur doivent être déployées avec cette version de l’app pour que les nouveaux identifiants et les durées personnalisées soient acceptés par une API distante. Aucune migration de base n’est nécessaire.

## Vérification et autocritique

Vérifications du 3 octobre 2026 : 131 tests Flutter et 20 tests serveur réussis, analyse Flutter et contrôle TypeScript sans problème, compilations web et serveur réussies.

Les tests couvrent les durées personnalisées, leurs limites, les fins exactes des 12 exercices, la pause des étapes, le retour au souffle libre du 4–7–8, les réponses tardives du serveur, le filtre Corps, la saisie avec clavier et le retour de la séance au catalogue. Un test de contrat compare les identifiants Flutter au catalogue serveur.

Les captures contrôlent 114 configurations : catalogue, durée avec clavier simulé, références, sept respirations, cinq pratiques écrites, retour au souffle libre et deux bilans, dans les deux thèmes, à 320 × 568, à 390 × 844 et à 390 × 844 avec texte à 150 %. Les erreurs sont collectées séparément du statut du script de capture. La mascotte utilise le PNG de secours du moteur de test, pas la vue native 3D.

La page rend le choix de durée plus visible grâce à une carte d’accueil compacte. Les filtres permettent d’explorer un catalogue plus long. À 150 %, les cartes passent en une colonne et demandent plus de défilement. Le guidage écrit est fonctionnel, mais ne procure pas encore l’expérience mains libres d’un accompagnement audio. La revue des références en ligne et le rendu sur téléphone restent les principales limites de cette livraison.
