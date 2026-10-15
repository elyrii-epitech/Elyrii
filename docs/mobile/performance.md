# Performance du frontend

## Mesures avant/après

Le [rapport du 14 octobre 2026](benchmarks/2026-10-14/README.md) conserve les
échantillons avant/après, les 32 cas comparés et les limites de mesure.
Les gains portent principalement sur l’ouverture des longues conversations,
la lecture d’historique, le rendu de pages anciennes, le cache dashboard et
les attentes évitées au démarrage. Les mesures de défilement sont mitigées ;
aucun gain uniforme de FPS ou de temps d’ouverture des écrans n’est établi.

Depuis `elyrii_app`, avec le SDK épinglé et les dépendances déjà installées :

```bash
bash benchmark/run_comparison.sh build/performance
```

Ce script compare le checkout courant à la base indiquée dans le rapport, avec
le même harness, et écrit les résultats dans `build/performance/`. Les logs et
essais intermédiaires restent dans ce répertoire ignoré par Git.

## Budgets et génération de la mascotte

Le runtime charge `assets/optimized/mascot.glb` ou la scène partagée
`assets/optimized/mascot_wardrobe.glb`. Le modèle original et les pièces sources
sont conservés pour permettre leur reconstruction ; ils ne sont pas déclarés
dans le bundle Flutter.

Les tests `test/core/mascot_asset_budget_test.dart` et
`test/core/mascot_wardrobe_asset_test.dart` vérifient tailles, triangles,
animations, ancrages et variantes. La garde-robe doit rester sous 4 Mo et
chaque tenue sous 70 000 triangles. Ces budgets de ressources ne sont pas des
mesures de framerate ou de mémoire GPU.

Depuis `elyrii_app/tool/mascot` :

```bash
npm ci
npm run build
```

Les versions d’outillage sont verrouillées dans `package-lock.json`.
Voir les [accessoires](mascot-accessories.md) et les [mouvements](velours-motion.md)
pour les autres sources et contrôles de génération.

## Profilage natif

Le test `integration_test/performance_test.dart`, lancé en mode profile sur
appareil physique, mesure l’initialisation de la démo, la navigation, les
frames Flutter et une page de messages anciens. La commande est dans le
[guide de développement](development.md).

Les tests VM/Linux utilisent des adaptateurs pour les plugins natifs et ne
mesurent pas le démarrage OS à froid, les frames WebGL, la mémoire native/GPU,
l’énergie ou la chauffe. Comparer les mêmes parcours et données sur les mêmes
appareils iOS/Android avec les outils de profilage des plateformes.
