# Développement frontend iOS et Android

Les seules cibles livrées sont **iOS et Android**. Utiliser Flutter **3.47.4** /
Dart **3.13.3**, définis dans `elyrii_app/.fvmrc`. Avec FVM : `fvm install`, puis
`fvm flutter …`. Sinon, installer cette version exacte et ajouter son `bin`
au `PATH`.

```bash
cd elyrii_app
flutter --version
flutter pub get --enforce-lockfile
flutter doctor -v
flutter run -d DEVICE_ID
```

En debug, l’environnement par défaut est `development`, gateway port **3001**.
L’émulateur Android utilise `10.0.2.2` et le simulateur iOS `localhost`.
Sur un téléphone physique, utiliser une gateway accessible en HTTPS :

```bash
flutter run -d DEVICE_ID --dart-define=ELYRII_API_URL=https://YOUR_DEVELOPMENT_GATEWAY
```

`ELYRII_API_PORT` change le port de développement local. L’ancien argument
`BASE_URL` reste accepté. Staging/production exigent une URL HTTPS explicite,
sans credentials incorporés et distante du loopback. Une release sans argument
d’environnement sélectionne production : elle ne cible pas silencieusement
la gateway locale de développement.

Android/iOS autorisent HTTP pour les seules exceptions locales du renderer et
du développement. L’application Android est `com.elyrii.elyrii_app` ; la signature
release exige `android/key.properties`. Ne pas versionner les credentials.
La cible CI iOS est une application simulateur debug.

## Architecture et tests

Enregistrer les services communs dans `lib/app/app_dependencies.dart`.
Les opérations par compte capturent une révision de session. Les repositories
valident le JSON externe via `decodeResponse` / `decodeListResponse` et réservent
les replis hors ligne aux erreurs typées admises. Un 401, une réponse invalide
ou une mutation refusée ne deviennent pas un succès issu du cache.

Journal/brouillons et messages/titres chat utilisent SQLite et AES-GCM. Les
clés sont conservées via Keychain/Keystore. L’adaptateur de test injecte SQLite
FFI : cela ne remplace pas une vérification des plugins sur iOS/Android.
Le chat conserve le header Bearer natif ; aucun contrat serveur n’est inventé.

Utiliser les contrôles communs accessibles pour les libellés, le clavier et
la réduction des animations. Construire les historiques non bornés via des
slivers paresseux. Pour Flutter Animate, utiliser
`animateRespectingMotion(context)`.

Les commandes pré-fusion figurent dans [CI/CD](ci-cd.md). Les tests couvrent
courses de session, credentials, stockage chiffré, purge/reprise, journal,
préférences hors ordre, annulation/délais réseau, chat, horloge/cycle de vie des
séances, routes, bootstrap, accessibilité et listes volumineuses.

## Intégration et profilage natifs

```bash
flutter test integration_test/frontend_flows_test.dart -d DEVICE_ID --dart-define=ELYRII_ENV=development
flutter drive --profile --no-dds -d PHYSICAL_DEVICE_ID --driver=test_driver/integration_test.dart --target=integration_test/performance_test.dart --dart-define=ELYRII_ENV=development
```

Le harness profile rapporte le temps d’ouverture du dashboard, le nombre de
frames, build p95 et raster p95. Contrôler également GPU/mémoire, galerie et
upload, libération du renderer, TalkBack/VoiceOver et texte agrandi sur les
appareils représentatifs avec DevTools. Les timings de tests widgets ne
prouvent pas la performance native.

Voir [le suivi de l’audit](frontend-audit-implementation.md) pour les migrations,
les résultats et les vérifications dépendantes des appareils et de la gateway.
