# Architecture du client Elyrii

État du code : 19 septembre 2026. Client Flutter organisé par fonctionnalité,
avec Provider pour l’état et l’injection, GoRouter pour la navigation, et un
client HTTP partagé vers la gateway.

## Organisation

```text
elyrii_app/lib/
  app/
    launch/                # introduction courte et démarrage
    router/                # GoRouter, guards, shell persistant, transitions
  core/
    config/                # URLs, configuration de la mascotte
    network/               # ApiClient, ApiException
    services/              # stockage sécurisé, thème, animation
    theme/                 # charte graphique
    glass/ et widgets/     # composants partagés, surfaces, rendu 3D
  features/
    auth/ chatbot/ coach/ dashboard/ gamification/
    journal/ mascot/ meditation/ settings/ …
```

Les pages consomment les providers. Les repositories portent les échanges
REST et le stockage local ; `ApiClient` ajoute le Bearer token et applique un
timeout. Le chat utilise un WebSocket authentifié vers la gateway.

## Démarrage et navigation

1. `main.dart` initialise la configuration, le thème et Liquid Glass.
2. Un seul `SecureStorageService` et un seul `ApiClient` sont partagés.
3. La session est restaurée depuis le stockage local : présence et expiration
   du JWT. Cette vérification n’attend pas le réseau.
4. `runApp` installe les providers globaux et `MyApp`.
5. La revalidation récupère `/user/me` en arrière-plan. Sa réponse hydrate aussi
   `UserProvider`, sans refaire ce GET. Réglages et mascotte suivent.
6. Dashboard, journal et coach chargent leurs données depuis leurs pages.
   Dashboard et journal dédupliquent les chargements simultanés identiques.

Providers globaux : thème, authentification, journal, chat, gamification,
profil/réglages, mascotte, dashboard et coach.

`AppRouter` utilise `StatefulShellRoute.indexedStack` pour les six branches
Accueil, Jardin, Journal, Méditation, Coach et Chat. Les guards gèrent la
connexion et la complétion du profil. L’état d’onglet est conservé ; la mascotte
cesse ses animations hors écran et libère son viewer après 15 secondes.

## Configuration réseau

Ordre de résolution : argument explicite, `ELYRII_API_URL`, ancien `BASE_URL`,
puis adresse locale. Le port local par défaut est **3001** et peut être remplacé
avec `ELYRII_API_PORT`. Android emulator utilise `10.0.2.2` ; iOS utilise
`localhost`. Fournir explicitement l’URL adaptée à l’environnement :

```bash
flutter run --dart-define=ELYRII_API_URL=http://127.0.0.1:3000
```

Tous les services REST passent par la gateway. Le chat ouvre `/chat/ws`.
Les diagnostics de santé des services ne s’exécutent qu’en debug, sur demande :

```bash
flutter run --dart-define=CHECK_BACKEND_HEALTH=true
```

## Données et persistance

- **Authentification** : tokens et identifiant dans `SecureStorageService`.
  La déconnexion efface la session locale même si l’appel distant échoue.
- **Chat** : `ChatHistoryService` utilise SQLite, tables de conversations et
  messages indexées par propriétaire. Écriture incrémentale et transactionnelle ;
  pages de 50 résumés/messages. Les getters du provider n’allouent plus une copie
  complète à chaque accès. Chaque réponse reste rattachée à la conversation
  d’origine, même pendant un changement de conversation.
- **Migration du chat** : l’ancien JSON global n’identifie pas son propriétaire.
  L’utilisateur doit donc confirmer « Récupérer mon ancien historique ». Le JSON
  reste conservé si l’import échoue et n’est supprimé qu’après la transaction.
- **Journal** : CRUD REST, cache de secours par identifiant de compte, lecture de
  l’ancien cache filtrée sur `userId`. Un 401/403 reste une erreur et ne devient
  pas artificiellement un succès grâce au cache. La déconnexion invalide aussi
  les requêtes du journal encore en vol et vide son état mémoire.
- **Éditeur du journal** : une seule sauvegarde en vol ; une nouvelle révision
  saisie pendant la requête reste à sauvegarder. Un échec ne produit pas le
  statut « Sauvegardé ».
- **Préférences** : thème et personnalisation utilisent SharedPreferences.

SQLite et le cache du journal ne sont pas présentés comme un coffre chiffré.
Le stockage des tokens est distinct. La synchronisation multi-appareils de
l’historique local n’est pas implémentée.

## Rendu et performances

Le dashboard utilise des sélecteurs ciblés au lieu d’un abonnement de toute la
page à quatre providers. Le journal et la feuille d’historique construisent
leurs cartes via des slivers à la demande. Les avatars sont décodés à leur
taille d’affichage physique.

La mascotte et son chapeau constituent une scène 3D unique ; les sources
originales restent dans le dépôt. La génération des variantes optimisées est
reproductible dans `elyrii_app/tool/mascot/`.

Voir [mesures, validations et limites](performance.md).

## Limites à ne pas confondre avec des garanties

- La pagination SQL du chat est locale ; `GET /journal` récupère encore la
  collection réseau complète. Une pagination serveur nécessite un contrat API.
- Pas de refresh token automatique ni de traitement global de tous les 401
  dans le client HTTP.
- Les tests de widget et le simulateur ne mesurent pas les FPS, la consommation
  ou la mémoire GPU d’un appareil réel.
- Le chat IA réel, Android sur appareil et les services distants ne sont pas
  certifiés par les fixtures locales de cette passe.
- Les cibles Windows/Linux/web ne sont pas validées ici ; le stockage sqflite
  de production vise les plateformes mobiles et macOS.

## Vérification

```bash
cd elyrii_app
flutter analyze --no-pub
flutter test --no-pub
flutter build ios --simulator --debug --no-pub
```

La CI utilise Flutter 3.47.4. Son artifact iOS est explicitement une application
**simulateur**, pas une archive signée ou une livraison TestFlight.
