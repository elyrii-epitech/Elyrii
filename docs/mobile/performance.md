# Performance du frontend

## Changements mesurables

Mesures sur les fichiers GLB et leur géométrie, pas sur le framerate.
La garde-robe a été actualisée le 3 octobre 2026 :

| Scène | Avant | Après |
| --- | ---: | ---: |
| Corps seul | 153 200 triangles | 62 404 triangles |
| Garde-robe, géométries masquées comprises | — | 76 522 triangles |
| Corps équipé d'une pièce de la garde-robe | — | moins de 65 000 triangles |
| Viewers natifs pour corps + accessoire | — | 1 |
| Fichier corps | 5 687 376 octets | 3 294 916 octets |
| Garde-robe chargée | — | 3 637 176 octets, un fichier |

Le corps contient **59,3 % de triangles en moins**, avec les 16 clips
d’animation et les deux skins conservés. Les douze accessoires suivent les
contrôles animés de la tête ou du buste.

Le bundle déclare le corps optimisé et la garde-robe : 6 932 092 octets pour ces
deux fichiers. Ce n’est pas une mesure de la taille finale de l’IPA.
Les textures embarquées dans les GLB n’ont pas été réduites :
aucun gain de mémoire GPU lié aux textures n’est revendiqué.

## Comportements modifiés

- Historique du chat SQLite : transactions par message, métadonnées séparées,
  lecture par pages de 50, propriétaires isolés et import explicite de l’ancien
  JSON. Plus de réécriture JSON complète à chaque message.
- Collection de messages exposée en vue non modifiable stable ; le rendu ne
  recopie pas tout l’historique pour accéder à un élément.
- Journal et historique : construction des cartes à la demande. Le réseau du
  journal n’est pas paginé côté serveur dans cette passe.
- Dashboard : abonnements ciblés aux parties d’état affichées.
- Mascotte : pause hors écran, prise en compte du cycle de vie et des animations
  réduites, destruction du viewer après 15 secondes hors écran puis recréation
  au retour. Un seul rendu WebGL pour le corps et son accessoire.
- Avatars : décodage dimensionné à la taille logique × densité de pixels.
- Démarrage : diagnostics réseau désactivés par défaut, suppression du double
  GET de profil et des préchargements dashboard/coach redondants ; introduction
  ramenée de 1 800 à 450 ms. Ce délai n’est pas une mesure du temps total de boot.
- Journal : sauvegardes sérialisées, état d’échec explicite, protection des
  nouvelles révisions et invalidation des réponses après déconnexion.

## Régénérer les modèles

Depuis `elyrii_app/tool/mascot` :

```bash
npm ci
npm run build
```

Versions d’outillage verrouillées dans `package-lock.json`. Les fichiers
générés vont dans `assets/optimized/`. Le test `mascot_asset_budget_test.dart`
vérifie les budgets du corps et ses clips. Le test
`mascot_wardrobe_asset_test.dart` vérifie les douze variantes, leurs ancrages et
les budgets de la garde-robe.

## Validation du 19 septembre 2026 et limites

Validation locale avec Flutter 3.47.4 / Dart 3.13.3 : **aucune alerte d’analyse,
100 tests réussis, compilation iOS simulateur debug réussie**. La suite teste
notamment la pagination de 125 messages et de 125 conversations, les lectures
concurrentes du chat, isolation des comptes, import corrompu, 1 000 notes dans
le journal, sauvegarde qui échoue et saisie pendant sauvegarde. Les tests UI
couvrent également les thèmes, le clavier et les ressources d’urgence.

Vérification sur un vrai **simulateur iPhone 17 Pro / iOS 26.4**, observé via
IOS Simulator Browser : dashboard/mascotte avec accessoire, navigation vers le
journal et défilement d’un jeu de 300 notes fictives, puis chat, historique et
feuille d’urgence. Une conversation de test a été enregistrée et retrouvée
après redémarrage Dart de l’application. Le serveur de test ne fournit pas
de WebSocket IA : l’état d’indisponibilité attendu est affiché. Ces données
viennent d’un serveur local de test : ce n’est pas une
validation du backend de production ni du service IA.

Le retour au dashboard après plus de 15 secondes dans le chat a également
été vérifié : la mascotte 3D et son accessoire sont à nouveau visibles.

La compilation signale encore que `flutter_inappwebview_ios` ne prend pas en
charge Swift Package Manager et utilise l’intégration compatible actuelle.
C’est un avertissement de dépendance à surveiller, pas une erreur de build ;
aucune modification des paramètres Xcode n’a été faite pour le masquer.

Les mesures FPS/p95, mémoire native/GPU, énergie et chauffe restent à effectuer
en mode profile sur un iPhone physique, sur les mêmes parcours avant/après.
Le simulateur en debug ne permet pas de conclure sur ces gains. Références :
[profilage Flutter](https://docs.flutter.dev/perf/ui-performance) et
[bonnes pratiques de rendu](https://docs.flutter.dev/perf/best-practices).

La réduction des textures et toute migration du rendu 3D vers une autre
technologie doivent être motivées par ces mesures, pas par une promesse de
performance non mesurée. Aucun changement du contrat backend ni déploiement
n’est inclus ici.
