# Méditer

La bibliothèque présente un lac sous le ciel violet, quatre durées et trois rayons éditoriaux. La capsule **3, 5, 10 ou 15 min** flotte sur le lac à la jonction du contenu. Au défilement, elle reste épinglée sous le titre compact, comme la capsule Série, Fleurs et Tenue de l’Accueil. Elle filtre la pratique mise en avant, les rayons et la liste complète. Toucher un exercice agrandit sa carte vers le centre de l’écran. Cet aperçu présente le nom, le rythme réel et les conseils. **Commencer** lance la séance avec la durée de la capsule, sans demander de la choisir à nouveau et sans audio.

L’aperçu est une carte opaque, arrondie sur les quatre côtés. Un tap hors de la carte, sa croix ou un glissement vers le bas la ferme sans démarrer de séance. Les autres présentations conservent leur ancrage en bas de l’écran.

La bibliothèque affiche neuf pratiques. Écoute des sons, Bienveillance et Auto-compassion restent dans le domaine et dans le contrat serveur, mais ne figurent pas dans cette présentation. La ligne **Reprendre** est absente, car aucune position de séance interrompue n’est enregistrée.

La séance s’ouvre hors du dock. Le lac conserve une échelle uniforme, sans étirer la lune. Le cercle et la pose d’Elyrii suivent les phases de la pratique et se figent en pause. Elyrii conserve la tenue de l’utilisateur, sans accessoire verrouillé ajouté. Le mouvement réduit fixe le cercle et la pose, sans arrêter le minuteur.

La fermeture d’une séance en cours demande confirmation. **Terminer la séance** enregistre la fin et ouvre un bilan avec le temps réellement écoulé, les cycles complets et cinq ressentis. Fermer le bilan ne relance pas une séance déjà enregistrée. **Voir le résumé** permet de le rouvrir. La série de jours n’est pas affichée dans ce bilan, faute de confirmation fraîche après l’enregistrement.

La bibliothèque propose uniquement les quatre durées de la capsule. Il n’y a pas de saisie de durée personnalisée. Les durées de l’Accueil et du Coach restent prises en charge, notamment les séances de une et deux minutes. Le contrôleur conserve sa plage de **1 à 1 439 minutes**. Toutes les feuilles partagent `AppSheetRoute`.

## Pratiques et séance

| Pratique | Guidage |
| --- | --- |
| Découverte | Souffle 3–3, sans rétention |
| Cohérence cardiaque | Souffle 5–5, six respirations par minute |
| Expiration longue | Expiration prolongée, repère 4–6 |
| Diaphragmatique | Attention au ventre, repère 4–6 sans rétention |
| Focus | Respiration carrée 4–4–4–4, avec **Pause** après l’expiration |
| Relaxation 4-7-8 | Jusqu’à quatre cycles, puis souffle naturel jusqu’à la fin du temps choisi |
| Ujjayi | Inspiration du yoga, repère 6–6 |
| Souffle conscient | Consignes écrites, respiration naturelle |
| Scan corporel | Consignes écrites, déplacement de l’attention dans le corps |
| Écoute des sons | Consignes écrites, attention au présent |
| Bienveillance | Consignes écrites, souhaits bienveillants |
| Auto-compassion | Consignes écrites, soutien envers soi |

Les cinq pratiques écrites ont des étapes pondérées. Le contrôleur répartit chaque étape sur une proportion de la durée totale, en incluant l’installation et le retour final. Il n’impose pas de cadence respiratoire à ces pratiques. La pause fige le temps et l’étape ; la reprise continue au même endroit. Il n’y a pas de piste audio enregistrée.

Les titres des séances restent entre les commandes d’interruption et de pause. Les longues consignes peuvent défiler. Le bilan affiche zéro cycle respiratoire pour une pratique à guidage écrit.

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

**Revue des références de pratique incomplète.** La revue précédente du 3 octobre 2026 signalait des refus HTTP 403 lors de la consultation des sources professionnelles. Cette refonte ne revalide pas ces références. Les captures ne constituent pas une validation éditoriale par ces organismes ou par un professionnel.

## API et compatibilité

`POST /meditation/sessions/start` reconnaît les 12 identifiants natifs du catalogue et accepte une durée entière de **1 à 1 439 minutes**, pour tous les exercices. Le catalogue publie les mêmes bornes dans `minDurationMinutes` et `maxDurationMinutes`. La curation de la bibliothèque est locale. Les identifiants historiques `breathing-5m`, `body-scan-10m` et `grounding-15m` restent acceptés.

Le client envoie l’identifiant de l’exercice et la durée choisie. La fin de séance est enregistrée même sans sélection d’un ressenti. Une sélection ultérieure met à jour ce ressenti. Une réponse de création arrivée après une interruption est annulée ; arrivée après la fin, elle est complétée. Une synchronisation échouée est signalée dans le bilan.

Le contrat utilise toujours `durationMinutes` et la base conserve sa colonne entière `duration_minutes`. Aucune migration de base n’est nécessaire. Le serveur doit être déployé avec cette version de l’app pour que les durées supérieures à l’ancienne borne de 180 minutes soient acceptées par une API distante.

## Vérification

Les tests Flutter couvrent les filtres de durée, la capsule épinglée, l’ouverture et l’annulation de la carte centrée, le démarrage avec la durée choisie, les étapes écrites, la pause et la confirmation de sortie. Ils vérifient aussi les quatre cycles du 4-7-8, le libellé **Pause**, les chiffres réels du bilan et le choix d’un ressenti. Les tests du contrôleur et du cycle de vie serveur restent en place.

Le test de contrat serveur compare les douze identifiants Flutter au catalogue serveur. Cette refonte frontend ne modifie ni le serveur ni ses données.

Les tests de widgets remplacent le modèle 3D par sa surface de test. Le rendu 3D, le lac et les feuilles sont aussi contrôlés dans le navigateur.
