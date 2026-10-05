# Choix du package Liquid Glass au 11 septembre 2026

## Décision

Elyrii conserve `liquid_glass_widgets` 1.4.3.

Pour une application Flutter Android et iOS, c'est le choix le plus solide parmi les packages évalués. Il combine une version stable publiée le 10 septembre 2026, une prise en charge explicite d'Impeller et de Skia, trois niveaux de qualité, une adaptation automatique aux performances, des réglages d'accessibilité et une bibliothèque complète de composants. Les écrans restent découplés du package par les composants Elyrii.

`liquid_glass_easy` 4.2.0 est le concurrent technique le plus proche. Son moteur sait réfracter sur Impeller et propose un chemin Skia dédié. Il reste moins adopté et sa version 4.0.0 a introduit plusieurs ruptures d'API récentes. Le migrer maintenant augmenterait le risque sans bénéfice décisif pour Elyrii.

## Comparaison

| Package | Version au 11/09/2026 | Pub points | Likes | Téléchargements sur 30 jours | Android et iOS | Verdict |
|---|---:|---:|---:|---:|---|---|
| `liquid_glass_widgets` | 1.4.3 | 160/160 | 265 | 60 278 | Impeller complet, Skia avec qualité plafonnée | Retenu |
| `liquid_glass_easy` | 4.2.0 | 160/160 | 258 | 11 055 | Chemins Impeller et Skia dédiés | Excellent moteur, API moins stabilisée |
| `liquid_glass_renderer` | 0.2.0-dev.4 | 150/160 | 886 | 25 239 | Android et iOS | Version de développement et moteur brut |
| `adaptive_platform_ui` | 0.1.111 | 160/160 | 386 | 10 622 | Plugin Android et iOS | Bibliothèque d'interface adaptative, pas un moteur Liquid Glass commun aux deux plateformes |
| `liquid_glass` | 0.0.2 | 115/160 | 18 | 499 | Déclaré multiplateforme | Peu maintenu, dépôt amont sans rapport direct avec le package |

Les compteurs proviennent de l'API publique pub.dev consultée le 11 septembre 2026. Ils mesurent l'adoption et la santé du package, pas la qualité visuelle à eux seuls.

## Raisons du choix

- `liquid_glass_widgets` 1.4.3 prend Android et iOS comme plateformes principales. Le niveau `premium` utilise Impeller. Le niveau `standard` reste disponible sur Skia. Le niveau `minimal` utilise un flou natif de repli.
- Le package publie une version stable. `liquid_glass_renderer` reste en version `dev` et demande de construire soi-même les composants, les replis et l'accessibilité.
- Son initialisation globale précharge les shaders. Son mode de qualité adaptative peut descendre de `premium` à `standard` ou `minimal` selon les temps de trame.
- La bibliothèque couvre les conteneurs, boutons, champs, feuilles, dialogues et barres de navigation. Elyrii peut donc supprimer ses anciens `BackdropFilter` manuels sans ajouter un second système.
- Le package n'ajoute aucune dépendance d'exécution en dehors du SDK Flutter.

## Conditions d'intégration

- Flutter 3.41.0 minimum, conformément au manifeste de `liquid_glass_widgets` 1.4.3.
- Appeler `LiquidGlassWidgets.initialize()` avant `runApp`.
- Envelopper l'application avec `LiquidGlassWidgets.wrap`, fournir `Theme.maybeBrightnessOf` pour `MaterialApp` et activer la qualité adaptative.
- Utiliser `ElyriiGlassSurface` et les contrôles du dossier `core/widgets/glass` comme points d'entrée. Aucun écran ne doit importer directement le package.
- Garder un rendu opaque de repli pour le contraste élevé.

## Sources primaires

- [API pub.dev de `liquid_glass_widgets`](https://pub.dev/api/packages/liquid_glass_widgets)
- [Score pub.dev de `liquid_glass_widgets`](https://pub.dev/api/packages/liquid_glass_widgets/score)
- [Dépôt et documentation de `liquid_glass_widgets`](https://github.com/sdegenaar/liquid_glass_widgets)
- [Prise en charge des plateformes](https://github.com/sdegenaar/liquid_glass_widgets/blob/main/docs/PLATFORM_SUPPORT.md)
- [Historique 1.4.3](https://github.com/sdegenaar/liquid_glass_widgets/blob/main/CHANGELOG.md)
- [API pub.dev de `liquid_glass_easy`](https://pub.dev/api/packages/liquid_glass_easy)
- [Score pub.dev de `liquid_glass_easy`](https://pub.dev/api/packages/liquid_glass_easy/score)
- [Documentation de `liquid_glass_easy`](https://github.com/AhmeedGamil/liquid_glass_easy)
- [Historique de `liquid_glass_easy`](https://github.com/AhmeedGamil/liquid_glass_easy/blob/main/CHANGELOG.md)
- [API et score de `liquid_glass_renderer`](https://pub.dev/api/packages/liquid_glass_renderer)
- [API et score de `adaptive_platform_ui`](https://pub.dev/api/packages/adaptive_platform_ui)
- [API et score de `liquid_glass`](https://pub.dev/api/packages/liquid_glass)
