# Application mobile Elyrii

Le frontend Flutter se trouve dans `elyrii_app`. Les cibles livrées sont
**iOS et Android**. Flutter **3.47.4** est épinglé dans `.fvmrc` ; Dart
**3.13.3** et les dépendances sont définis dans `pubspec.yaml` et son lockfile.

## Démarrage

```bash
cd elyrii_app
flutter pub get --enforce-lockfile
flutter run -d DEVICE_ID
```

En développement, la gateway utilise le port 3001 (`10.0.2.2` sur émulateur
Android, `localhost` sur simulateur iOS). Pour un téléphone, fournir une gateway
accessible avec `--dart-define=ELYRII_API_URL=https://YOUR_GATEWAY`.

## Documentation

| Guide | Contenu |
| --- | --- |
| [Développement](development.md) | SDK, installation, environnement et exécution native |
| [Architecture](architecture.md) | Navigation, sessions, réseau et stockage par compte |
| [Fonctionnalités](features.md) | Parcours pris en charge et données associées |
| [Design system](design.md) | Thème, composants communs, accessibilité et assets |
| [Dépendances](dependencies.md) | Rôle des packages et inventaire reproductible |
| [CI/CD](ci-cd.md) | Contrôles, tests, builds et artefacts |
| [Livraison](release.md) | Migration, configuration des services et validation native |
| [Accessibilité](accessibility.md) | Tests automatiques et protocole TalkBack/VoiceOver |
| [Méditation](meditation.md) | Catalogue, durées, guidage et contrat API |
| [Personnalisation](mascot-accessories.md) | Garde-robe, progression et reconstruction des assets |
| [Mouvements de la mascotte](velours-motion.md) | Clips, transitions et génération |

## Vérification locale

Depuis la racine du dépôt, avec le SDK épinglé dans le `PATH` :

```bash
bash scripts/flutter_ci_check.sh
```

Les tests natifs sont décrits dans le guide de développement.

## Points d’entrée

- `elyrii_app/lib/main.dart` : initialisation de l’application ;
- `elyrii_app/lib/app/app_dependencies.dart` : services et portée de session ;
- `elyrii_app/lib/app/router/app_router.dart` : routes et navigation ;
- `elyrii_app/lib/core/config/api_config.dart` : configuration de la gateway ;
- `elyrii_app/lib/core/network/api_client.dart` : transport REST partagé ;
- `.github/workflows/flutter-check-and-docs.yml` : validation et documentation API.
