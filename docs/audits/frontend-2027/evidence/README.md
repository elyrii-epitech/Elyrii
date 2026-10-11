# Preuves de l’audit frontend 2027

Commit `4b90d68ff8c09fd9e357f40ed78e5422bb80aa18`, 10 octobre 2026, Flutter 3.47.4 / Dart 3.13.3.

- `sdk.log`, `pub-get.log` : outillage et résolution du lockfile.
- `analyze.log`, `format.log` : contrôles statiques sans modification applicative.
- `tests.log` : 245 tests unitaires/widgets existants réussis.
- `metrics.json` : résumé et couverture par fichier, sur les lignes instrumentées LCOV.
- `probes.log` : 10 reproductions de défauts confirmées. **Leurs tests attendent les comportements défectueux actuels.**
- `layout.json` : résultat des 56 observations de rendu, avec diagnostics complets. **8 configurations contiennent 11 erreurs de débordement.**
- `layout.log` : exécution du collecteur. « All tests passed » indique sa terminaison, pas l’absence de défauts.
- `screenshots/` : sélection de captures de widgets, données synthétiques, polices chargées. Les services natifs et le viewer 3D ne sont pas validés par ces images.
- `outdated.json` : versions verrouillées et versions proposées ; **ce n’est pas un scan CVE**.
- `doctor.log` : limites de l’environnement pour Android/iOS et dépendances natives.

Sources des reproductions : [probes_test.dart](../probes_test.dart) et [layout_test.dart](../layout_test.dart). Commandes et interprétation dans le [rapport](../rapport.md#11-reproduction-et-dossier-de-preuves).

L’archive livrée contient également les 56 captures et le LCOV complet. Les logs peuvent référencer les chemins d’exécution du workspace ; ces chemins ne sont pas nécessaires à la compréhension des défauts.
