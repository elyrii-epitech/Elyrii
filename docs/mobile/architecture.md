# Architecture du client Elyrii

État du code : 6 octobre 2026. Client Flutter organisé par fonctionnalité,
avec Provider pour l’état et l’injection, GoRouter pour la navigation, et un
client HTTP partagé vers la gateway.

## Organisation

```text
elyrii_app/lib/
  app/
    app_dependencies.dart  # composition et durée de vie des services
    launch/                # introduction courte et démarrage
    router/                # GoRouter, guards, shell persistant, transitions
  core/
    config/                # URLs, configuration de la mascotte
    network/               # ApiClient, ApiException
    services/              # stockage sécurisé, thème, animation
    storage/               # SQLite par plateforme, chiffrement du contenu
    diagnostics/           # événements bornés sans contenu privé
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

1. `main.dart` installe les handlers d'erreurs et affiche immédiatement le bootstrap.
2. La configuration, les locales et les plugins s'initialisent avec une erreur
   récupérable, une échéance et un bouton de reprise.
3. `AppDependencies` possède les services et providers. Il reprend d'abord les
   purges de compte inachevées puis restaure la session sécurisée sans attendre
   le réseau.
4. Chaque changement de session invalide le client HTTP et tous les états du
   compte, puis hydrate le profil, les préférences et la gamification.
5. Les pages chargent leurs données avec des requêtes dédupliquées. Le routeur
   est recréé au changement de compte et libéré avec son propriétaire.

Providers globaux : thème, authentification, journal, chat, gamification,
profil/réglages, mascotte, dashboard et coach.

`AppRouter` utilise `StatefulShellRoute.indexedStack` pour les six branches
Accueil, Jardin, Journal, Méditation, Coach et Chat. Les guards gèrent la
connexion et la complétion du profil. L’état d’onglet est conservé ; la mascotte
cesse ses animations hors écran et libère son viewer après 15 secondes.

## Configuration réseau

Ordre de résolution : argument explicite, `ELYRII_API_URL`, ancien `BASE_URL`,
puis adresse locale uniquement en développement. Les autres environnements exigent une URL HTTPS explicite. Le port local par défaut est **3001** et peut être remplacé
avec `ELYRII_API_PORT`. Android emulator utilise `10.0.2.2` ; iOS utilise
`localhost`. Fournir explicitement l’URL adaptée à l’environnement :

```bash
flutter run --dart-define=ELYRII_API_URL=http://127.0.0.1:3001
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
- **Journal** : CRUD REST, entrées et brouillons SQLite chiffrés par compte, lecture de
  l’ancien cache filtrée sur `userId`. Un 401/403 reste une erreur et ne devient
  pas artificiellement un succès grâce au cache. La déconnexion invalide aussi
  les requêtes du journal encore en vol et vide son état mémoire.
- **Éditeur du journal** : une seule sauvegarde en vol ; une nouvelle révision
  saisie pendant la requête reste à sauvegarder. Un échec ne produit pas le
  statut « Sauvegardé ».
- **Préférences** : thème et personnalisation utilisent SharedPreferences.

Les titres/messages du chat et les entrées/brouillons du journal sont chiffrés
avec AES-GCM et une clé par compte dans le stockage sécurisé, avec authentification
du propriétaire et de la ressource. Les caches en clair sont migrés. La suppression
d'un compte tente toutes les purges et détruit sa clé ; un marqueur conserve les
étapes à reprendre après un échec. Une déconnexion conserve les données locales
protégées pour une prochaine connexion. Le chiffrement navigateur ne protège pas
contre du JavaScript compromis dans la même origine. La synchronisation entre
appareils de l'historique chat local reste hors contrat.

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
- Pas de refresh token automatique ; un 401 de la session courante ferme
  localement cette session, sans affecter un compte connecté ultérieurement.
- Les tests de widget et le simulateur ne mesurent pas les FPS, la consommation
  ou la mémoire GPU d’un appareil réel.
- Le chat IA réel, Android sur appareil et les services distants ne sont pas
  certifiés par les fixtures locales de cette passe.
- Les cibles de livraison sont uniquement iOS et Android. Les builds natifs,
  les plugins sur appareils et le profilage matériel restent à exécuter dans
  les environnements correspondants.

## Vérification

```bash
cd elyrii_app
flutter analyze --no-pub
flutter test --no-pub
flutter build ios --simulator --debug --no-pub
```

La CI utilise Flutter 3.47.4. Son artifact iOS est explicitement une application
**simulateur**, pas une archive signée ou une livraison TestFlight.

Le détail des corrections et des commandes reproductibles figure dans
[le suivi de l’audit](frontend-audit-implementation.md).
