# Corrections de l’audit frontend 2027

État au 10 octobre 2026. Branche `frontend`, base
`4b90d68ff8c09fd9e357f40ed78e5422bb80aa18`, synchronisée avec son origine avant
les modifications. Ce bilan suit les **30 constats** du [rapport initial](rapport.md).
Les corrections sont locales ; aucun commit, push ou déploiement n’a été effectué.

Le périmètre est l’application Flutter **iOS et Android**, les API nécessaires à
ses nouveaux parcours, les tests et la CI. L’activation email F07 et le
renouvellement des access tokens de 15 minutes F08 restent exclus, conformément
à la demande. Les informations sur l’éditeur, les contacts, les marchés, l’âge
minimum et les traitements des conversations IA ont été laissées de côté à la
demande de l’utilisateur : F01, F02 et F06 restent reportés. Les politiques
existantes n’ont pas été complétées avec des informations supposées.

## Changements et état des 30 constats

« Appliqué » décrit un changement vérifié dans le périmètre indiqué. Les
conditions de configuration, d’exploitation et de validation native figurent
explicitement dans la dernière colonne.

Le [suivi CSV](suivi-corrections.csv) reprend ces états avec les priorités du
backlog initial, conservé séparément.

| ID | État | Résultat et preuve / limite |
| --- | --- | --- |
| F01 | Reporté | Documents juridiques, identité de l’éditeur et accès aux documents avant inscription restent à traiter lorsque les informations seront disponibles. La case d’acceptation possède toutefois un contrôle natif accessible. |
| F02 | Reporté | Aucune nouvelle garantie d’hébergement, d’entraînement, de conservation ou d’effet du mode « confidentialité stricte ». Son comportement actuel est conservé. |
| F03 | Appliqué | Cache dashboard AES-GCM, associé au propriétaire et à la période, TTL de 24 h ; anciennes clés en clair supprimées. Tests de lecture chiffrée, d’isolation et de succès malgré un échec de cache. |
| F04 | Appliqué, exploitation à configurer | Signalement accessible d’une réponse IA, motif et réponse sélectionnée uniquement ; enregistrement serveur, quota de 20/jour/compte, file et clôture réservées aux modérateurs autorisés. Tests HTTP et PostgreSQL concurrents. Il faut désigner les modérateurs et organiser le traitement réel. |
| F05 | Amélioré | Détection française contextualisée, cas négatifs, bannière persistante et aide d’urgence disponible sans détection. Tests de phrases positives/négatives. Une heuristique de texte ne constitue pas une garantie clinique de détection de détresse. |
| F06 | Reporté | Règle d’âge et parcours mineurs inchangés en attendant les choix produit/juridiques laissés de côté. |
| F07 | Exclu | Activation email conservée en l’état, sans implémentation supplémentaire. |
| F08 | Exclu | Pas de renouvellement automatique ajouté aux sessions de 15 minutes. Les mécanismes existants de JWT et de refresh ne sont pas modifiés. |
| F09 | Appliqué | Révisions de session, de chargement et de mutation empêchant un ancien GET de remplacer une création, modification ou suppression réussie ; tri et chargement des pages protégés. Tests de réponses hors ordre. |
| F10 | Appliqué | L’accusé serveur reste un succès si la copie locale échoue, avec avertissement explicite. UUID de création conservé dans le brouillon, contrainte d’unicité par compte, effets métier exécutés une seule fois. Douze créations concurrentes sur PostgreSQL produisent une seule note. |
| F11 | Appliqué | Labels natifs persistants, autofill email/mot de passe, toggle nommé, erreurs associées aux champs, case d’acceptation native et soumission clavier. Tests de sémantique et des interactions. |
| F12 | Appliqué sur les écrans testés | En-têtes défilants lorsque nécessaire, disposition responsive, navigation adaptée au grand texte, formulaires/dialogues/mascotte sans réduction forcée de police. 105 rendus sur 15 écrans, de 100 à 300 %, avec paysage et largeur de 280 points. |
| F13 | Appliqué sur les états testés | Couleurs de texte de statut corrigées, bordures de champs renforcées, boutons remplis opaques et contraste conservé pendant l’appui ; focus visible à deux anneaux. Contraste raster vérifié sur 60 états et tests de palette dans les deux thèmes. |
| F14 | Appliqué | Identifiants de propositions rejetées conservés pendant la session ; les GET tardifs ne les réintroduisent pas. Test de concurrence. |
| F15 | Appliqué | Transport de démonstration local couvrant les parcours pris en charge ; les opérations de compte réelles sont refusées et aucune requête distante ne part pour la session démo. Tests d’isolation. |
| F16 | Appliqué, mail à configurer | Demande et confirmation accessibles ; code aléatoire à usage unique de 15 minutes, hash uniquement en base, limitation des requêtes et réponses uniformes. Confirmation atomique et invalidation des refresh sessions. Sans configuration mail, indisponibilité explicite. Les access tokens existants peuvent subsister jusqu’à leur expiration, conformément à F08 exclu. |
| F17 | Appliqué par clarification du produit | L’interface décrit une copie locale et une reprise explicite ; elle ne promet plus une synchronisation automatique absente. Brouillons chiffrés, sauvegardes sérialisées et créations idempotentes. Pas de nouvelle outbox automatique. |
| F18 | Appliqué | Badges calculés sur les défis réellement terminés, seuils visibles 1/3/7/12/24/36, état verrouillé annoncé et lisible. |
| F19 | Appliqué par retrait de la promesse | Le réglage de push non opérationnel a été remplacé par un statut d’indisponibilité exact. Le réglage haptique fonctionnel est conservé. |
| F20 | Appliqué | Export JSON des données serveur appartenant au compte, complété par les conversations et brouillons locaux déchiffrés ; partage explicite, contrôle de propriétaire avant ouverture du partage et nettoyage des fichiers privés. Tests PostgreSQL d’isolation et tests de changement de compte. Les coordonnées juridiques restent reportées avec F01. |
| F21 | Appliqué par limitation explicite | Français seul déclaré et proposé ; aucune localisation anglaise incomplète annoncée. Une livraison anglophone demanderait un travail de traduction distinct. |
| F22 | Appliqué | Horodatage des notes converti en heure locale avant affichage. |
| F23 | Appliqué localement, exploitation à valider | Diagnostics techniques persistants bornés à 100 événements / 7 jours, catégories génériques sans texte privé, token ou exception brute ; partage volontaire. Tests d’expiration, de bornage et de réinitialisation. Collecte et suivi opérationnels de production restent à configurer. |
| F24 | Appliqué | Android utilise les versions Flutter ; les paramètres affichent la version/build de l’application installée via PackageInfo. La progression des numéros doit être respectée à chaque livraison. |
| F25 | Préparé, validation native restante | Harness profile physique avec budget de frames, workflows Android signé / iOS technique, contrôle ELF 16 KiB et zipalign. Aucun résultat de performance physique, WebGL, mémoire GPU ou signature de distribution n’est déduit des tests Linux. |
| F26 | Appliqué | Pagination serveur et SQLite par 100 notes, curseurs stables à la milliseconde + UUID, filtres/tri conservés, nombre calculé sans déchiffrement global. Tests sur 230 dates égales et 10 000 notes chiffrées ; chaque page locale ne déchiffre que 100 lignes. |
| F27 | Appliqué en partie, suivi continu | 48 versions de paquets existants mises à jour et 5 paquets ajoutés, lockfile imposé, actions épinglées, Dependabot, inventaire CycloneDX de 173 composants avec graphe Dart et JS/GLB embarqués. Dix versions plus récentes restent incompatibles avec les contraintes retenues, dont des versions liées au SDK ; l’inventaire natif et le traitement opérationnel des advisories demandent les builds et une revue dédiée. |
| F28 | Appliqué, scénario Android natif restant | Reprise du résultat image_picker sur Android liée au propriétaire de la demande ; copies dans le cache privé, limite de 4 Mo, nettoyage des fichiers abandonnés après 7 jours, purge par compte. Tests de fichiers garantissant la conservation de l’original de galerie et des autres comptes. |
| F29 | Appliqué, assistance native restante | Régressions de session/cache/pagination/fichiers, rendus multi-tailles, contrôles sémantiques, clavier, dialogues, graphique non vide et signalement IA à 300 %. CI et scénarios natifs fournis ; protocole TalkBack/VoiceOver dans le dossier dédié. |
| F30 | Appliqué côté contenu | Conseils reformulés sans promesses de traitement ni badges de preuve non démontrés ; liens explicites OMS, NHS et NCCIH. Une revue éditoriale professionnelle reste nécessaire si les allégations, le public ou les conseils évoluent. |

## Accessibilité approfondie

Le [dossier d’accessibilité](accessibilite.md) décrit les critères, les preuves,
les limites de l’automatisation et un parcours d’évaluation reproductible. La
cible est WCAG 2.2 AA adaptée à une application native. Le RGAA sert de grille
complémentaire ; cette passe ne constitue pas une déclaration réglementaire de
conformité ni une certification anticipée pour 2027.

Les corrections portent aussi sur les états intermédiaires : erreurs de
formulaire, chargement de bouton, sélection, focus clavier, boîte de dialogue,
contenu défilé et lecture textuelle des données de graphique. Les textes
restent agrandis ; aucun FittedBox ne réduit les titres pour masquer un
débordement.

## Validation reproductible

Environnement : Flutter **3.47.4**, Dart **3.13.3**, Bun **1.3.10**,
PostgreSQL **16** dans un conteneur de test jetable. Les fixtures sont
synthétiques. SQLite FFI et AES-GCM sont exécutés réellement ; les plugins
natifs et les services distants de l’application Flutter utilisent des
adaptateurs de test. Les tests API de concurrence utilisent PostgreSQL réel.

| Contrôle | Résultat |
| --- | --- |
| Résolution Flutter verrouillée | `flutter pub get --enforce-lockfile` réussi |
| Analyse Flutter | Aucune alerte après correction |
| Formatage | 247 fichiers vérifiés, aucune modification requise |
| Suite Flutter | 403 tests réussis ; détails et couverture dans [les preuves](preuves-implementation/verification.json) |
| Couverture LCOV | 74,46 % : 9 254 / 12 428 lignes dans 163 fichiers instrumentés ; ne remplace pas les parcours natifs |
| Rendus accessibles | 105 configurations, aucune exception de rendu enregistrée |
| Sémantique | 60 états × 4 contrôles réussis ; méthode et correction de coordonnées du helper documentées |
| API | 38 tests réussis, dont 5 scénarios d’intégration PostgreSQL ; TypeScript et build Bun réussis |
| Migration additive | Appliquée deux fois sur la base jetable, sans erreur ; pas appliquée en production |
| Inventaire | 173 composants, références de graphe et hash du lockfile vérifiés |
| Documentation API | Dartdoc 9.0.11 : 171 bibliothèques publiques, 0 avertissement, 0 erreur |
| Contrôle ELF | Acceptation de fixtures 16/64 KiB et refus de fixtures 4 KiB, ELF32 et ELF64 ; artefacts Android réels encore à construire |
| Configuration native/CI | YAML, manifeste Android et plist iOS vérifiés syntaxiquement |

Les résultats détaillés, les commandes, le périmètre de mesure et les empreintes
des fichiers sont conservés dans [les preuves](preuves-implementation/verification.json).
Les 105 captures et les journaux d’exécution sont également rassemblés dans
l’archive de corrections, séparément de l’archive de l’audit initial.

Le fichier `probes_test.dart` conservé avec l’audit initial reproduisait les
défauts avant correction. Il ne fait pas partie de la suite actuelle : les
régressions qui vérifient les comportements corrigés se trouvent dans
`elyrii_app/test/`.

## Données et déploiement

La [checklist de mise en production](validation-production.md) décrit la
migration SQL, le webhook mail, l’autorisation des modérateurs, les quotas,
les builds natifs et les essais physiques. Ces préconditions ne sont pas
remplacées par le résultat des tests unitaires.

Le cache journal contient les pages déjà consultées ; il ne garantit pas que
toutes les notes distantes sont disponibles hors ligne ni qu’une suppression
faite depuis un autre appareil a déjà été observée. L’export local réunit les
données réellement présentes sur cet appareil avec l’export serveur.

Les JSON de partage contiennent les données en clair après consentement :
nettoyage des copies temporaires privées après 24 h au prochain démarrage ou
nouvel export, et à la suppression du compte. Les fichiers d’avatar abandonnés
sont nettoyés après 7 jours lors de l’initialisation. Les copies déjà envoyées
vers une autre application ne sont pas contrôlées par Elyrii.

## Rapports antérieurs

Le [bilan mobile précédent](../../mobile/frontend-audit-implementation.md)
concerne 23 constats sur une autre base Git. Il est conservé pour l’historique.
Ses identifiants F01–F23 et ses anciens résultats ne doivent pas être confondus
avec les 30 constats de cet audit.
