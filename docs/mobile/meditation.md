# Méditation : durées libres et catalogue

La préparation de séance présente un en-tête simple, la mascotte sans halo ni décor derrière elle et un catalogue calme. Le bouton `i` en haut à droite et les liens « Conseils et références » sont retirés de l’interface. Les références éditoriales restent conservées dans cette documentation et dans les données des exercices.

La durée se choisit librement à la minute, de **1 minute à 23 h 59 (1 439 minutes)**, avec deux roues heures/minutes en français. Aucun raccourci de durée prédéfinie n’est proposé. Le choix s’applique à la confirmation de la feuille ; annuler conserve la durée précédente. Une durée nulle ne permet pas de confirmer.

Le catalogue contient 12 exercices, filtrables par respiration, présence, corps et bienveillance. Le choix d’un exercice conserve la durée choisie. La hiérarchie distingue l’accueil, la durée, les catégories et les pratiques. Le bouton de lancement reste accessible pendant le défilement et dégagé du dock.

Le verre est réservé aux commandes et à la navigation. Les descriptions et les exercices utilisent des surfaces de contenu sobres. Le dock et sa bulle de chat utilisent une teinte plus transparente qui laisse transparaître le fond des pages, sans modifier les matériaux de verre des autres composants. Le mode de contraste élevé conserve un fond opaque pour la lisibilité.

## Choix du sélecteur et du verre

Les [recommandations Apple sur les pickers](https://developer.apple.com/design/human-interface-guidelines/pickers) décrivent un sélecteur de compte à rebours à roues heures/minutes, limité à 23 h 59. Les valeurs suivent un ordre prévisible. La feuille reste à proximité de la valeur éditée et propose toutes les minutes. La [documentation `countDownDuration`](https://developer.apple.com/documentation/uikit/uidatepicker/countdownduration) confirme la limite de 86 340 secondes, soit 1 439 minutes.

Les [recommandations Apple sur les matériaux](https://developer.apple.com/design/human-interface-guidelines/materials) réservent Liquid Glass aux commandes et à la navigation au-dessus du contenu, avec un usage mesuré. Elles motivent l’allègement du dock et des surfaces du catalogue. Les [recommandations sur les boutons](https://developer.apple.com/design/human-interface-guidelines/buttons) demandent une action principale identifiable et une zone d’interaction d’au moins 44 × 44 points.

## Pratiques et séance

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

**Revue des références de pratique incomplète.** La revue précédente du 3 octobre 2026 signalait des refus HTTP 403 lors de la consultation des sources professionnelles. Cette refonte de l’interface ne revalide pas ces références : leur contenu actuel et leur disponibilité restent à contrôler. Les captures ne constituent pas une validation éditoriale par ces organismes ou par un professionnel. Les sources Apple ci-dessus ont été consultées pour le sélecteur et le design.

## API et compatibilité

`POST /meditation/sessions/start` reconnaît les 12 identifiants natifs du catalogue et accepte une durée entière de **1 à 1 439 minutes**, pour tous les exercices. Le catalogue publie les mêmes bornes dans `minDurationMinutes` et `maxDurationMinutes`. `durationMinutes` dans le catalogue serveur reste une suggestion ; cette métadonnée ne produit pas de choix prédéfinis dans la page. Les identifiants historiques `breathing-5m`, `body-scan-10m` et `grounding-15m` restent acceptés.

Le client envoie l’identifiant de l’exercice et la durée choisie. La fin de séance est enregistrée même sans sélection d’un ressenti. Une sélection ultérieure met à jour ce ressenti. Une réponse de création arrivée après une interruption est annulée ; arrivée après la fin, elle est complétée. Une synchronisation échouée est signalée dans le bilan.

Le contrat utilise toujours `durationMinutes` et la base conserve sa colonne entière `duration_minutes`. Aucune migration de base n’est nécessaire. Le serveur doit être déployé avec cette version de l’app pour que les durées supérieures à l’ancienne borne de 180 minutes soient acceptées par une API distante.

## Vérification de la refonte

Le test de contrat serveur compare les identifiants Flutter au catalogue serveur. Il couvre les douze exercices avec des durées arbitraires, les 1 439 minutes disponibles, les bornes du catalogue, les anciens identifiants et le rejet de zéro, des nombres non entiers, des types incorrects et des durées supérieures à 23 h 59.

Exécution du 3 octobre 2026 : `bun test modules/meditation/meditation.validation.test.ts` dans `elyrii_server` — **6 tests réussis, 0 échec**. Les dépendances ont été restaurées avec `bun install --frozen-lockfile`, sans modification du verrouillage.

Exécution Flutter du 3 octobre 2026 : `flutter test --no-pub` — **163 tests réussis, 0 échec**. Les régressions couvrent notamment les roues, leur annulation et leur confirmation, les catégories, les annonces accessibles sans doublons, le démarrage, la pause, les réponses tardives du serveur, les deux thèmes, le contraste élevé, les petits écrans et le texte agrandi. Le bouton de lancement est vérifié au-dessus du dock à 320 × 568 et à 390 × 844 avec texte à 150 %.

Le guidage écrit ne dispose pas d’un accompagnement audio. Les tests de widgets utilisent le PNG de secours de la mascotte ; le rendu 3D et le verre sur téléphone nécessitent une vérification native.
