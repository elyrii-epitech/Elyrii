# Application de l’audit frontend

Ce document suit les 23 constats de l’audit de la branche `frontend`, effectué
sur le commit `e4624470b63fd05e1523115acaf1d91e0269be38`. Les modifications
concernent l’application Flutter, ses configurations de plateforme, ses tests,
sa CI et sa documentation. Le backend et son protocole n’ont pas été modifiés.

Les cibles livrées sont **exclusivement iOS et Android**, conformément à la
précision donnée pendant l’application de l’audit. Le constat F10, conditionné
à une livraison web, est hors périmètre. Les ajouts destinés uniquement au web
ont été retirés du code, des dépendances, des artefacts et de la CI.

L’environnement reproductible est Flutter **3.47.4** et Dart **3.13.3**, avec
la version Flutter définie dans `elyrii_app/.fvmrc` et un lockfile vérifié par
`flutter pub get --enforce-lockfile`. Les choix reposent sur les API disponibles
et sur des invariants testables pour assurer une maintenance durable.

## Suivi des constats

| Constat | Modification appliquée | Vérification / limite |
| --- | --- | --- |
| F01 — Isolation des comptes | `AppDependencies` possède la session ; changement de compte, logout et 401 invalident les requêtes et réinitialisent tous les états. Préférences, coach, onboarding et caches sont rattachés au propriétaire. | Réponses tardives, bascule de compte et conservation des données d’un autre compte testées. |
| F02 — Authentification incomplète / tardive | Révision de session, opérations de credentials sérialisées, soumission unique et validation de token/identifiant. Les formulaires observent réellement le chargement. | Login tardif après logout, token absent et résultats hors ordre testés. |
| F03 — Repli des credentials | Aucun repli vers des préférences en clair. Migration à sens unique vers le stockage sécurisé ; échecs de lecture, écriture et suppression propagés. Entitlements Keychain ajoutés ; Auto Backup Android désactivé selon la configuration du plugin. | Tests du service sécurisé ; Keychain/Keystore réels à contrôler sur les plateformes natives. |
| F04 — Environnement release | Environnements explicites ; staging/production exigent une URL HTTPS distante valide au démarrage. HTTP limité aux exceptions locales nécessaires. Signature Android release obligatoire, sans clé debug de remplacement. | Validation de configuration testée ; CI produit des artefacts techniques de développement. Distribution signée à valider avec les credentials de l’organisation. |
| F05 — Suppression de compte | Purge du journal, des brouillons, du chat, de l’onboarding, des préférences et de la clé de contenu. Chaque purge est tentée ; un marqueur durable permet une reprise au prochain démarrage. Les écritures en cours sont terminées avant suppression. | Purge, reprise après échec et préservation d’un autre compte testées. |
| F06 — Journal et brouillons | `JournalStore` SQLite par compte, contenu chiffré, écritures sérialisées, snapshots cohérents après CRUD et brouillons persistants. Migration des anciens contenus identifiés par propriétaire. | Suppression puis lecture hors ligne, réouverture de brouillon et absence de contenu en clair dans SQLite testées. |
| F07 — Routes | Onboarding rattaché au compte ; route avatar et argument photo conservés ; route de séance sans contrôleur valide redirigée vers le catalogue. | Guards et arguments avatar testés. |
| F08 — Dates françaises | Initialisation centralisée des données de locale avant affichage des dates. | Régression de l’historique ancien testée. |
| F09 — Retour de méditation | `PopScope` observe la transition vers l’état terminé et libère le retour système. | Fin de séance puis retour système testés. |
| F10 — Livraison web conditionnelle | Hors périmètre : l’application est livrée uniquement sur iOS et Android. SQLite, galerie/recadrage et WebSocket utilisent leurs implémentations natives. | Aucun build ni job web ajouté ; aucun contrat d’authentification navigateur à mettre en place. |
| F11 — Préférences hors ordre | Patchs optimistes ordonnés, commandes sérialisées, snapshot confirmé et cache par propriétaire ; un ancien résultat ne remplace pas une modification récente. | Réponses hors ordre, rollback et bascule de compte testés. |
| F12 — Temps / séances | Chronométrage monotone par `Stopwatch`, rattrapage du temps écoulé, pause à l’arrière-plan et reprise explicite. Contrôleur libéré dans tous les chemins de lancement/fin. | Horloge contrôlée et cycle de vie testés. |
| F13 — Livraison chat | Transport injectable, délai de connexion et échéance par réponse ; état `pending/delivered/failed`, reprise explicite de la même bulle et identifiant de requête distinct par tentative. Le message est sauvegardé avant d’accepter l’envoi. | Timeout, réponse tardive, erreur de stockage, mauvaise corrélation et changement de compte testés. |
| F14 — Contrats réseau | Erreurs HTTP/transport/protocole typées ; validation aux frontières repositories ; 401 rattaché à la bonne session. Délai total et annulation des requêtes, y compris lecture du corps et upload. Lectures concurrentes dédupliquées. | JSON invalide, données requises absentes, annulation, corps bloqué et déduplication testés. Pas de refresh automatique sans contrat existant. |
| F15 — Hors ligne explicite | Cache dashboard par période/propriétaire, fraîcheur et TTL ; repli limité aux indisponibilités admises. Humeur annulée si la mutation échoue, conservée si le serveur l’a acceptée mais le refresh échoue. Coach ne transforme pas un refus en succès. | 401 avec cache, périodes, erreur de mutation et absence d’écrasement par un ancien GET testés. |
| F16 — Défis volumineux | Sections `SliverList.builder`, clés stables, snapshots immuables et chargement partagé en cours. Commandes concurrentes bornées. | Fixture de 1 000 défis : construction limitée aux éléments visibles et quatre lectures pour un chargement concurrent. Pagination serveur non inventée. |
| F17 — Budget graphique | Décodage des images à la taille utile et au DPR, sélection d’image bornée, surfaces répétées légères. Garde-fous de visibilité/activité du renderer 3D conservés ; budgets GLB protégés. | Tests de taille/triangles ; harness de traces UI/raster fourni. Galerie/recadrage et mesures de performance sur appareil physique encore nécessaires. |
| F18 — Accessibilité | Actions communes accessibles au clavier et aux technologies d’assistance, libellés d’icônes, cibles d’au moins 44 pixels logiques pour les composants concernés, contraste d’erreur corrigé et verre opaque en contraste élevé. Réduction du mouvement respectée pour les animations décoratives. | Semantics, clavier, contraste et absence de ticker répétitif testés. TalkBack/VoiceOver réels restent à contrôler. |
| F19 — Responsabilités | Composition explicite ; HTTP, parsing et persistance mascotte déplacés vers le repository ; repository bilan effectivement injecté ; sections dashboard, défis et bilan extraites. Alternatives inutilisées retirées. | Analyse statique, tests existants et scénarios des repositories/providers. |
| F20 — Modèles | Copies défensives et collections imbriquées immuables ; champs requis validés ; valeurs optionnelles inconnues conservées ou interprétées explicitement. Présentation d’humeur séparée des données. | Mutation des collections source, DTO invalides et statuts optionnels inconnus testés. |
| F21 — Bootstrap / ressources | Affichage immédiat du bootstrap, délai et reprise ; propriétaire explicite des providers, clients et router. Guards `mounted`/session après attente ; erreurs des commandes 3D consommées et référence WebView détachée à la fermeture. Diagnostics bornés sans texte privé ni credentials. | Échec puis reprise du bootstrap, disposal, sorties asynchrones et erreur d’un renderer fermé testés. |
| F22 — CI reproductible | Workflow frontend unique déclenché sur `frontend/dev/main`, qualité commune puis builds et intégrations Android/iOS, documentation. SDK local/CI commun, lockfile imposé, format vérifié sans mutation. | Équivalents locaux exécutables ; GitHub Actions et protections de branche nécessitent leur exécution/configuration côté dépôt. |
| F23 — Frontières réelles | Régressions de l’audit, SQLite réel et WebSocket IO local avec handshake Bearer, scénarios d’intégration native et harness de performance. | Résultats locaux ci-dessous ; aucun résultat de plugin natif ou de performance physique n’est déduit de tests widgets. |

## Stockage et migration

Les titres/messages de chat et le journal/brouillons sont chiffrés avec
AES-GCM 256 bits. La clé est propre au compte ; l’authentification du contenu
inclut son propriétaire et son usage. La clé est stockée séparément via
`SecureStorageService`. Une erreur de stockage n’autorise pas l’écriture en clair.
Les anciennes lignes SQLite identifiées sont migrées avant consultation.

L’ancien historique JSON `chat_history_v1` n’indique aucun propriétaire : son
import reste explicite. Il ne peut pas être affecté automatiquement au prochain
compte connecté. Les anciens caches du journal sont filtrés par propriétaire.
La suppression d’un compte préserve les données des autres comptes.

Les clés utilisent le stockage sécurisé natif iOS/Android. Les tests locaux
substituent ce plugin pour vérifier les règles d’erreur et d’isolation ; ils
ne prouvent pas le comportement réel de Keychain/Keystore.

## Transport chat natif

Le transport conserve `Authorization: Bearer …` dans le handshake WebSocket.
Une connexion sans token est refusée avant ouverture. Aucun token n’est ajouté
à l’URL et aucun repli d’authentification par simple identifiant n’est utilisé.
Chaque tentative de renvoi conserve l’identifiant du message et utilise une
nouvelle corrélation, ce qui empêche une réponse tardive de terminer la nouvelle
tentative. Aucun renvoi automatique n’est effectué sans garantie de déduplication
du protocole. Le backend et ses mécanismes d’authentification restent inchangés.

## Vérification locale

Résultats du 6 octobre 2026, sous Flutter **3.47.4** / Dart **3.13.3** :

| Contrôle | Résultat |
| --- | --- |
| `flutter pub get --enforce-lockfile` | Réussi, résolution verrouillée |
| `dart format --output=none --set-exit-if-changed lib test tool integration_test test_driver` | 231 fichiers, aucune modification requise |
| `flutter analyze --no-pub` | Aucune alerte |
| `flutter test --no-pub --coverage` | **241 tests réussis**, durée d’environ 2 min 23 s |
| Couverture LCOV | **67,21 %** des lignes instrumentées : 7 781 / 11 578, 158 fichiers |
| `dart doc --output doc/api` | 166 bibliothèques publiques documentées ; aucun avertissement ni erreur |
| YAML CI, XML Android, plists/entitlements iOS | Syntaxe valide |
| Périmètre Git | Aucun changement backend, web ou macOS ; application mobile, CI et documentation frontend |

La couverture mesure les fichiers instrumentés par cette suite ; elle ne
remplace pas les scénarios critiques ni la validation des plugins natifs.
Les commandes et préconditions sont décrites dans [CI/CD](ci-cd.md) et
[Development](development.md).

Les scénarios unitaires/widgets sont exécutés sous Linux avec SQLite FFI réel
et un serveur WebSocket IO local. Les services distants sont remplacés par des
fixtures, et le stockage sécurisé par un adaptateur de test. Cela valide les
invariants du frontend et le transport natif, pas la gateway de production.

## Vérifications dépendantes de l’environnement

- Exécuter les jobs Android et iOS sur leurs runners, puis les parcours avec
  Keychain/Keystore, sélection/upload d’image et WebView 3D réels.
- Exécuter `integration_test/performance_test.dart` en mode profile sur des
  appareils physiques représentatifs : UI/raster p95, dépassements du budget
  de frame, mémoire, comportement du renderer en arrière-plan et énergie.
- Contrôler TalkBack/VoiceOver, texte agrandi et contraste sur les appareils
  livrés. Les tests automatiques couvrent des critères ciblés.
- Effectuer les scénarios réseau de bout en bout avec la gateway réelle,
  notamment chat, upload d’avatar et expiration de session.
- Définir les checks requis de branche dans GitHub et fournir URL de production
  et clés de distribution pour les releases signées.

L’environnement Linux de cette intervention ne possède ni SDK Android,
ni Xcode, ni appareil physique. Les validations natives restent à exécuter sur
les runners et appareils indiqués ci-dessus.
