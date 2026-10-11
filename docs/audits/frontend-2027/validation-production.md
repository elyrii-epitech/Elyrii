# Préconditions de livraison des corrections

Ce document complète le [bilan](implementation.md) et le
[protocole d’accessibilité](accessibilite.md). Les modifications sont vérifiées
localement ; aucun déploiement, envoi d’email réel ou action de modération
sur des données de production n’a été effectué.

## Migration et ordre de livraison

1. Sauvegarder la base et tester la restauration en staging ; mesurer la durée
   des créations d’index sur un volume représentatif. Les index standards de
   cette migration peuvent verrouiller des écritures pendant leur création.
2. Appliquer
   [`20261010_frontend_reliability.sql`](../../../elyrii_server/migrations/20261010_frontend_reliability.sql)
   par le mécanisme de migration du déploiement avant d’activer le nouveau
   backend. La migration est additive et a été rejouée deux fois sur une base
   PostgreSQL 16 jetable. Ne jamais utiliser le `drizzle-kit push --force` de la
   CI de test comme procédure de migration de production.
3. Livrer le backend, vérifier les routes existantes puis les nouvelles avec
   des comptes de staging. L’absence de paramètres de pagination conserve
   l’ancien format tableau du journal ; les nouveaux clients demandent des
   pages de 100 avec ordre et curseur.
4. Configurer le mail, l’accès modérateur et les limites de passerelle ci-dessous.
   Livrer ensuite l’application native testée et signée selon la plateforme.
5. Vérifier la création idempotente, les effets de défis, la lecture paginée,
   l’export propriétaire, le signalement et la récupération depuis l’application.

Les UUID de création sont uniques par compte ; les anciennes lignes peuvent
conserver un identifiant de requête nul. Le curseur du journal utilise la date
tronquée à la milliseconde et l’UUID, avec un index correspondant, pour éviter
les pertes liées à la précision PostgreSQL/JavaScript.

Un rollback de l’application/backend peut conserver les colonnes, tables et
index additifs. Ne pas supprimer les notes, signalements ou tokens de
récupération avec un rollback improvisé. Les accès, sauvegardes et durées de
conservation des nouveaux signalements doivent entrer dans l’exploitation ;
leur description juridique demeure reportée à la demande de l’utilisateur.

## Récupération de mot de passe

Configurer côté serveur :

| Variable | Contrat |
| --- | --- |
| `PASSWORD_RESET_MAIL_WEBHOOK` | URL HTTPS sans identifiant, mot de passe, query ni fragment ; les redirections sont refusées. |
| `PASSWORD_RESET_MAIL_SECRET` | Secret serveur transmis au webhook par `Authorization: Bearer …`, jamais à l’application. |
| `PASSWORD_RESET_TRUSTED_PROXY_IPS` | Facultatif : liste séparée par virgules des adresses IP exactes des proxys réellement connectés au serveur. |

Le webhook reçoit un POST JSON :

```json
{
  "template": "password-reset",
  "to": "compte-fictif@example.invalid",
  "code": "code-base64url-aleatoire-a-usage-unique",
  "expiresInMinutes": 15
}
```

Le modèle doit afficher le code copiable et la durée, sans le journaliser ni
l’intégrer dans une URL de tracking. Le webhook répond 2xx après prise en
charge ; timeout de 10 s. Les échecs de livraison invalident le hash émis et
produisent uniquement une catégorie technique générique. L’absence de
configuration retourne 503 avec un message honnête. Lorsque configurée, la
demande valide retourne 202 de manière uniforme pour les adresses connues et
inconnues ; cette réponse ne prouve pas la livraison de l’email.

Le code est issu de 256 bits aléatoires, stocké uniquement sous forme de
SHA-256, valable 15 minutes et consommé atomiquement une seule fois. Le
nouveau mot de passe est borné à 12–128 caractères et hashé par Argon2id. La
confirmation supprime les refresh sessions du compte ; les access tokens
existants peuvent continuer jusqu’à leur expiration. Leur renouvellement et
les parcours d’activation email restent volontairement hors périmètre.

Exécuter en staging : adresse inconnue, livraison réussie, indisponibilité du
webhook, code expiré, deux confirmations concurrentes, demandes répétées et
mot de passe correct après confirmation. Aucun vrai message n’a été envoyé
pendant cet audit.

Les routes publiques ont des limites de corps de 1 KiB (demande) et 4 KiB
(confirmation), et des quotas par processus de 10 / 30 requêtes par fenêtre
de 15 minutes. La carte des identités est bornée à 10 000, les identités
supplémentaires étant refusées lorsque pleine. Un délai SQL d’une minute par
compte protège aussi l’émission sur plusieurs instances. Le quota IP en
mémoire n’est pas un quota distribué : appliquer en complément des limites
partagées au niveau de la passerelle et du fournisseur mail.

L’adresse réelle du peer Bun est utilisée. `X-Real-IP` est accepté seulement
si ce peer figure explicitement dans la liste de confiance et que la valeur
est une IP unique valide. Le proxy doit écraser le header fourni par le client.
Tester que des headers arbitraires ne permettent pas de contourner les limites
et que la configuration ne regroupe pas tous les visiteurs sous un seul quota.

## Signalement et modération IA

`POST /user/ai-reports` demande une session, une réponse sélectionnée et un
motif. Le propriétaire est pris dans la session ; aucun propriétaire, statut
ou historique envoyé par le client n’est accepté comme autorité. Limite de
16 000 caractères de contenu, corps de 96 KiB et quota atomique de 20
signalements par fenêtre glissante de 24 h et par compte. Les signalements demeurent dans la
base d’Elyrii ; aucune transmission automatique à un tiers n’est ajoutée.

Configurer `MODERATION_ADMIN_USER_IDS` avec les UUID exacts des comptes
autorisés, séparés par des virgules. Une liste vide refuse tout accès. Ces
comptes accèdent à `GET /user/moderation/reports` (50 signalements ouverts au
maximum) et à `PUT /user/moderation/reports/:reportId` avec
`{"status":"REVIEWED"}` ou `{"status":"ACTIONED"}`. Le rôle n’est pas
déduit d’un champ modifiable par le client. Il s’agit d’une API de traitement,
pas d’une nouvelle console d’administration livrée dans l’application.

Désigner une personne responsable, la fréquence de lecture, les délais de
prise en charge, l’escalade pour contenus dangereux et la procédure de
correction du système IA. Vérifier en staging le refus d’un utilisateur
ordinaire, l’accès d’un modérateur, la clôture et l’absence d’une clôture
non autorisée. La disponibilité de la route ne démontre pas que les
signalements sont effectivement traités.

## Données et diagnostics

Vérifier l’export avec deux comptes, des données supprimées, des tags/media,
des conversations et des brouillons locaux. Le serveur utilise un snapshot
cohérent, exclut mots de passe/tokens et joint les relations au propriétaire.
Le partage natif vérifie encore la session après préparation du fichier. Les
exports temporaires privés expirent après 24 h avec nettoyage au prochain
démarrage ou export ; suppression du compte les purge également. Les copies
déjà partagées relèvent de la destination choisie.

Les diagnostics locaux ne contiennent que catégories techniques, événements
et horodatages UTC, 100 événements au maximum sur 7 jours. Ils sont partagés
volontairement, sans upload automatique. L’équipe d’exploitation doit encore
définir comment recevoir et suivre ces diagnostics, mesurer les taux d’erreur
et d’indisponibilité, alerter et corréler les incidents sans collecter le texte
privé. Ne pas ajouter de payloads de chat/journal ou de secrets aux logs.

## Dépendances et builds

Le workflow frontend impose le lockfile, l’analyse, les tests et les builds
techniques ; le workflow serveur vérifie TypeScript, les tests PostgreSQL et
le build Bun sur une base jetable. Les actions sont épinglées par SHA et
Dependabot ouvre les mises à jour compatibles. Les mises à jour majeures, en
particulier du renderer 3D dont certains internes sont utilisés, exigent une
revue des contrats et des tests natifs.

La documentation API utilise Dartdoc **9.0.11** épinglé. Le générateur 9.0.6
embarqué dans le SDK plantait sur les imports documentaires de dépendances
avec des fins de ligne CRLF ; la version corrigée est exécutée explicitement
en local et dans le job documentaire.

L’inventaire CycloneDX généré par `elyrii_app/tool/frontend_sbom.py` contient
173 composants, le graphe Dart, les hashes d’archives Pub, le JS model-viewer
embarqué et les GLB. La version amont du JS embarqué n’est pas déterminée :
il est identifié par son hash, avec son en-tête de licence. L’inventaire ne
constitue ni un scan de vulnérabilités ni une revue exhaustive des licences.
Ajouter la fermeture Gradle/CocoaPods après build, examiner les avis Pub,
GitHub et fournisseurs, attribuer un responsable et un délai de correction,
et consigner un exercice de traitement d’un advisory. Les obligations CRA,
si applicables au produit, demandent une qualification séparée ; aucune
qualification juridique n’est inventée dans ce dossier.

Le workflow manuel `frontend-release-validation.yml` ne publie rien. Il
prend une origine API HTTPS et utilise l’environnement GitHub
`frontend-release-validation`, avec : `ANDROID_KEYSTORE_BASE64`,
`ANDROID_STORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`.
Il construit AAB/APK release signés, contrôle chaque segment ELF natif pour
les pages de 16 KiB, contrôle le ZIP par `zipalign -c -P 16 -v 4`, puis supprime
les fichiers temporaires de signature. Le job iOS produit un artefact
technique release sans signature ; une distribution iOS demande encore les
certificats, profiles, capabilities et la validation Xcode de l’organisation.

Cet environnement Linux ne dispose pas d’Android SDK, Xcode, appareil ni
secrets de distribution. La politique réseau ne permet pas tous les dépôts
natifs nécessaires. Les workflows n’ont pas été déclenchés et les nouveaux
binaires natifs n’ont donc pas été validés ici. Les fixtures ELF prouvent le
comportement du contrôle, pas la compatibilité de l’APK final.

## Mesures sur appareils

Exécuter `integration_test/performance_test.dart` avec `flutter drive`, le
driver fourni et `--profile` sur matériel physique. Le test refuse le mode
debug et expose le budget configurable `ELYRII_FRAME_BUDGET_MS`, par défaut
16,7 ms, pour le p95 des frames build/raster Flutter. Adapter à 8,3 ms pour une
cible de 120 Hz. Mesurer les deux modes sur les modèles de téléphone retenus.

Ce harness mesure l’initialisation de la démo après démarrage du processus de
test et les frames dashboard ; **il ne mesure pas un lancement OS à froid,
les frames WebGL, la mémoire native/WebView/GPU ou l’énergie**. Mesurer ces
éléments séparément avec les outils Android/iOS. Compléter les
[budgets de ressources existants](../../mobile/performance.md) par des valeurs
observées et un appareil de référence, et comparer avant/après sur les mêmes
parcours : dashboard/mascotte équipée, long journal, chat, méditation,
arrière-plan/reprise et navigation prolongée.

Le benchmark local de 100/1 000/10 000 notes démontre que seule une page de
100 lignes est déchiffrée. Ses durées SQLite FFI en mémoire sur VM Linux ne
sont pas des promesses de latence sur téléphone.

Avant livraison, exécuter aussi les parcours TalkBack/VoiceOver décrits dans
le [dossier d’accessibilité](accessibilite.md), les permissions galerie,
la reprise Android après destruction du picker, les partages natifs, la
suppression/reprise de purge et l’expiration de session. Renseigner résultats,
modèles, versions, traces et anomalies ; aucun de ces essais physiques n’est
marqué réussi par défaut.
