# Connexion du mobile au backend — 22 octobre 2026

Le serveur de développement écoute sur le port 3000, également utilisé par
défaut par Flutter. iOS utilise `localhost`, Android Emulator `10.0.2.2`.
Pour les tests locaux sur un port différent :

```sh
flutter run --dart-define=ELYRII_ENV=development --dart-define=ELYRII_API_URL=http://127.0.0.1:3188
```

La production conserve le VPS existant et son URL HTTPS fournie au build par
`ELYRII_API_URL` / `ELYRII_RELEASE_API`. Aucun hôte local n’est utilisé par défaut
dans une release. Aucun déploiement VPS n’est effectué par ces changements.

## Session native

Les réponses de connexion, d’inscription et de vérification retournent `token`
et `refreshToken`. Les cookies restent disponibles pour les anciens clients.
Le mobile conserve les deux dans le stockage sécurisé et transmet le token
tournant dans le JSON de `POST /auth/refresh`. Une rotation concurrente ne peut
réutiliser deux fois la même session. Le renouvellement est partagé entre les
requêtes HTTP et les nouvelles connexions WebSocket.

Un compte restauré avec un token d’accès expiré et un refresh disponible peut
encore accéder à ses données locales pendant une coupure réseau. Un refresh
refusé termine la session. Déconnexion et changement de compte invalident les
écritures d’identifiants encore en vol. Le logout transmet aussi le refresh pour
supprimer la session serveur.

## Activation email sur le VPS

La production exige toujours la vérification d’adresse. Configurer :

| Variable | Valeur attendue |
| --- | --- |
| `PUBLIC_URL` | URL HTTPS publique du VPS, sans query, fragment ou credentials. |
| `EMAIL_VERIFICATION_MAIL_WEBHOOK` | Endpoint HTTPS du fournisseur mail, sans query, fragment ou credentials. |
| `EMAIL_VERIFICATION_MAIL_SECRET` | Secret serveur transmis par `Authorization: Bearer …`. |

À défaut des deux variables spécifiques au mail de vérification, le serveur
utilise `PASSWORD_RESET_MAIL_WEBHOOK` et `PASSWORD_RESET_MAIL_SECRET`.
Le fournisseur doit accepter le nouveau template :

```json
{
  "template": "email-verification",
  "to": "fixture@example.test",
  "verificationUrl": "https://API_DU_VPS/auth/verify-email#TOKEN_A_USAGE_UNIQUE",
  "expiresInMinutes": 1440
}
```

Le fragment n’est pas envoyé dans les logs de requêtes de la passerelle. La page
de confirmation le retire de l’URL et appelle le POST de vérification. Après
confirmation, l’utilisateur revient dans Elyrii pour se connecter. Un lien ne
peut être consommé qu’une fois, même avec des confirmations simultanées.

Sans configuration mail valide, l’inscription retourne 503 au lieu d’annoncer
une activation impossible. Après une panne de livraison, une nouvelle tentative
d’inscription avec les mêmes identifiants permet de renvoyer le lien. Aucun
véritable email n’a été envoyé pendant les tests.

## Contrats corrigés

- Création des réglages résistante aux requêtes simultanées du démarrage.
- Acceptation/refus de défi avec son template, pour conserver titre et détails.
- Suppression transactionnelle des anciennes relations journal/défis qui ne
  cascadaient pas depuis le compte ; refus des anciens tokens après suppression.
- Historique du contexte IA sans duplication du message courant ni erreurs
  techniques injectées dans l’historique. Le payload privé n’est plus journalisé.
- Réponses de chat corrélées avec les IDs attendus par l’application.

Les tables et index de la migration `20261010_frontend_reliability.sql` restent
nécessaires sur le VPS. Cette passe n’ajoute pas de migration supplémentaire.
Livrer le backend avant le mobile pour que les nouvelles sessions natives
reçoivent leur refresh token ; les sessions déjà ouvertes devront se reconnecter
une fois pour en obtenir un.

## Validation reproductible

Les tests connectés créent et suppriment des comptes fictifs. Ils nécessitent
une base locale jetable **elyrii_frontend_test**, jamais la base du VPS.

```sh
# Préparer une base jetable avec le schéma Drizzle, puis exporter DB_HOST,
# DB_PORT, DB_USER, DB_PASSWORD et DB_NAME=elyrii_frontend_test.
cd elyrii_server
bun run test:mobile
```

Le script démarre et arrête sa propre API sur `127.0.0.1:3188` ;
`MOBILE_TEST_API_PORT` permet de choisir un autre port libre. Il refuse un port
occupé ou une configuration de base non locale. La CI serveur exécute ce test
HTTP après ses tests de repositories PostgreSQL.

Pour vérifier les vrais repositories et décodeurs Dart avec cette API maintenue
en exécution dans un autre terminal :

```sh
cd elyrii_app
flutter test --no-pub test/frontend/connected_backend_test.dart \
  --dart-define=MOBILE_API_INTEGRATION=true \
  --dart-define=MOBILE_TEST_API_URL=http://127.0.0.1:3188
```

Résultats locaux : analyse Flutter sans alerte, 414 tests Flutter réussis (le
test connecté est désactivé dans la suite ordinaire), 43 tests backend avec
PostgreSQL, 8 scénarios HTTP connectés, contrôle TypeScript et build Bun réussis.
Le test Dart connecté a aussi réussi avec le vrai broker Kafka et un worker IA
local de test : handshake Bearer, renouvellement avant reconnexion, persistance
des deux côtés et deux conversations distinctes. Le contenu du modèle IA de
production n’est pas évalué par ce worker.

Le simulateur iOS 26.4 a également affiché le tableau de bord avec le profil
et l’humeur enregistrés sur cette API locale. Un message saisi depuis le chat
natif a traversé WebSocket/Kafka et affiché la réponse du worker de test.
Le build Xcode a réussi ; l’attachement Flutter de développement a ensuite
échoué faute d’espace disque, sans empêcher l’application installée de fonctionner.
Cette validation ne couvre ni un appareil physique ni le VPS de production.
