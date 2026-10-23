# Frontend CI — iOS et Android

Le workflow Flutter unique est `.github/workflows/flutter-check-and-docs.yml`.
Son nom **Flutter Style, Test & Docs** est utilisé par la publication des
API docs.

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
| Frontend API documentation | Dartdoc 9.0.11 épinglé, artefact `dartdoc-html` conservé pour le pipeline documentaire |

Les builds et l’intégration dépendent du job qualité. Les protections de
branche et les checks obligatoires doivent être configurés dans GitHub par
les administrateurs ; un fichier de workflow ne les active pas à lui seul.

## Compatibilité et intégration native

Le wrapper Android utilise **Gradle 8.14.3**, avec Java 17, AGP 8.12.1 et
Kotlin 2.2.20. Ces versions respectent les minima de Flutter 3.47.4 et des
plugins de partage/version installés ; les vérifications de compatibilité du
SDK restent actives.

Les parcours attendent la fin de l’écran de lancement et font défiler les
contrôles avant de cliquer, afin de fonctionner sur les tailles d’écran des
simulateurs.
Un scénario natif dédié vérifie la réouverture de l’historique chiffré et sa
purge, avec les vrais plugins SQLite et Keychain/Keystore. Il couvre notamment
les commandes SQLite qui renvoient une ligne et exigent `rawQuery`, même
lorsqu’elles configurent une valeur comme `PRAGMA secure_delete = ON`.

## Commandes locales

Depuis `elyrii_app`, avec la version du SDK de `.fvmrc` :

```bash
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test tool integration_test
flutter analyze --no-pub
flutter test --no-pub --coverage
flutter build apk --debug --no-pub --dart-define=ELYRII_ENV=development
flutter build ios --simulator --debug --no-pub --dart-define=ELYRII_ENV=development
flutter test integration_test/frontend_flows_test.dart -d DEVICE_ID --dart-define=ELYRII_ENV=development
dart pub global activate dartdoc 9.0.11
dart pub global run dartdoc --output doc/api
```

`bash scripts/flutter_ci_check.sh`, depuis la racine du dépôt, exécute la
résolution verrouillée, le formatage sans mutation, l’analyse et les tests.

Sur ce poste, vérifier d’abord les parcours dans le navigateur. Ne pas lancer
de simulateur ou d’émulateur local. Un build ou une installation sur téléphone
demande une autorisation explicite après la revue navigateur.
Les jobs natifs GitHub Actions ne constituent une preuve qu’après leur exécution.

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
