# Frontend CI — iOS et Android

Le workflow Flutter unique est `.github/workflows/flutter-check-and-docs.yml`.
Son nom **Flutter Style, Test & Docs** est conservé pour la publication des
API docs existante. Le workflow redondant `flutter-build.yml` est retiré.

Les seules cibles de l’application sont **iOS et Android**. Les pushes et PR
sur `frontend`, `dev` et `main` déclenchent les vérifications lorsque le code
Flutter, sa documentation mobile ou sa CI change. Le lancement manuel reste
possible.

L’action partagée lit Flutter **3.47.4** depuis `elyrii_app/.fvmrc`, puis impose
`flutter pub get --enforce-lockfile`. La validation locale utilise exactement
le même SDK et Dart **3.13.3**.

| Job | Vérification / artefact |
| --- | --- |
| Frontend quality | Formatage sans mutation, analyse, tests unitaires/widgets et couverture LCOV |
| Android technical build | Java 17, APK debug de développement |
| iOS simulator technical build | Application debug de développement pour simulateur, runner macOS |
| Frontend Android integration | Émulateur API 35, bootstrap, persistance et navigation avec les plugins natifs |
| Frontend iOS integration | Simulateur iPhone disponible du runner macOS, bootstrap, persistance native et navigation |
| Frontend API documentation | `dart doc`, artefact `dartdoc-html` conservé pour le pipeline documentaire |

Les builds et l’intégration dépendent du job qualité. Les protections de
branche et les checks obligatoires doivent être configurés dans GitHub par
les administrateurs ; un fichier de workflow ne les active pas à lui seul.

## Commandes locales

Depuis `elyrii_app`, avec la version du SDK de `.fvmrc` :

```bash
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test tool integration_test test_driver
flutter analyze --no-pub
flutter test --no-pub --coverage
flutter build apk --debug --no-pub --dart-define=ELYRII_ENV=development
flutter build ios --simulator --debug --no-pub --dart-define=ELYRII_ENV=development
flutter test integration_test/frontend_flows_test.dart -d DEVICE_ID --dart-define=ELYRII_ENV=development
dart doc --output doc/api
```

Android exige son SDK et iOS Xcode sur macOS. L’environnement Linux de
l’intervention ne possède ni Android SDK, ni Xcode : les builds natifs et les
tests d’émulateur/simulateur n’y sont pas exécutés. Les workflows sont fournis,
sans prétendre qu’un run GitHub Actions a eu lieu.

## Distribution

Une build production/staging exige une URL explicite de gateway HTTPS :

```bash
flutter build appbundle --release --dart-define=ELYRII_ENV=production --dart-define=ELYRII_API_URL=https://YOUR_GATEWAY
flutter build ipa --release --dart-define=ELYRII_ENV=production --dart-define=ELYRII_API_URL=https://YOUR_GATEWAY
```

Remplacer l’exemple par l’URL réelle. La signature Android release nécessite
`android/key.properties` et un keystore de distribution ; aucune clé debug
n’est utilisée en repli. iOS exige les certificats et profils de l’organisation.
Les artefacts CI de développement ne sont pas des livraisons de production.
Aucun déploiement ni envoi vers les stores n’est effectué par cette CI.
