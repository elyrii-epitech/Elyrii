# Dépendances frontend iOS et Android

La source de vérité est `elyrii_app/pubspec.yaml` et son lockfile versionné.
Flutter **3.47.4** / Dart **3.13.3** sont utilisés localement et dans la CI ;
`flutter pub get --enforce-lockfile` vérifie la résolution.

| Dépendance | Responsabilité |
| --- | --- |
| Flutter, flutter_localizations, intl | UI, locales prises en charge et dates françaises/anglaises initialisées |
| provider, go_router | État/injection des fonctionnalités et shell de navigation persistant |
| http, http_parser | Transport HTTP commun annulable et types MIME des fichiers |
| cross_file | Lecture/upload des photos natives via l’interface `XFile` du picker |
| flutter_secure_storage | Credentials et clés de contenu par compte, sans repli en clair |
| cryptography | AES-GCM avec authentification liée au propriétaire et à la ressource |
| shared_preferences | Préférences sans contenu privé, fraîcheur des caches, marqueurs de purge |
| sqflite, sqflite_common, path | SQLite iOS/Android, interface commune et chemins normalisés |
| sqflite_common_ffi | Dépendance de développement pour les tests SQLite réels sous Linux |
| flutter_animate, liquid_glass_widgets | Animations respectant le système et primitives de verre communes |
| flutter_3d_controller 2.3.0, visibility_detector | Renderer mascotte existant, suspension et libération selon la visibilité |
| image_picker, image_cropper | Galerie et recadrage natifs iOS/Android |
| uuid, url_launcher, cupertino_icons | Identifiants de corrélation/ressources, ressources externes et icônes |
| flutter_test, integration_test, flutter_lints | Tests unitaires/widgets, intégration native et analyse statique |
| image ^4.8.0, flutter_launcher_icons, flutter_native_splash | Fixtures et outils de génération des assets |

Le transport chat utilise `dart:io` pour le WebSocket authentifié avec Bearer.
Les polices Poppins sont embarquées, sans téléchargement Google Fonts.
Les ajouts réservés au navigateur sont retirés : pas de runtime SQLite web,
de transport cookie web ni de recadrage navigateur dans cette intervention.

Les upgrades doivent repasser les tests d’assets, les builds iOS/Android et
les parcours natifs avant fusion. Les dossiers de plateformes créés par
Flutter ne constituent pas une promesse de livraison sur ces plateformes.
