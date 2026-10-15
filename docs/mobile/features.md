# Fonctionnalités mobiles

Les modules se trouvent dans `elyrii_app/lib/features`. Les données privées
locales sont rattachées au compte ; la démo utilise une session isolée.

| Module | Parcours | Données |
| --- | --- | --- |
| Authentification | Connexion, inscription, récupération du mot de passe, démo, déconnexion | API d’authentification ; credentials dans Keychain/Keystore |
| Profil | Configuration, modification et choix d’avatar | API utilisateur ; copies d’images dans le cache privé |
| Dashboard et bilan | Humeur, statistiques, progression et raccourcis | API et cache dashboard chiffré par compte/période |
| Journal | Création, modification, suppression, tri et chargement de notes anciennes | API et SQLite paginés par 100 ; brouillons chiffrés et reprise explicite |
| Chat | Conversations, réponses corrélées, reprise d’envoi, copie et signalement | WebSocket Bearer ; historique SQLite chiffré, pages de 50 |
| Jardin | Défis disponibles/actifs/terminés, propositions IA et badges | API ; fraîcheur de 30 secondes, actualisation explicite et après commande |
| Coach | Conseils, besoins et activités ouvrant le journal, une séance ou le guidage | Catalogue local et sessions du repository coach |
| Méditation | 12 pratiques, durée de 1 à 1 439 minutes, pause/reprise et bilan | Contrôleur monotone et synchronisation des séances avec l’API |
| Mascotte | Couleurs, finitions, 15 accessoires répartis sur quatre zones, sauvegarde explicite | Scène GLB partagée ; préférences et progression par compte |
| Paramètres | Thème, haptique, profil, export, diagnostics et suppression du compte | Préférences, version installée, API et partage natif volontaire |

Le chat expose les ressources d’urgence indépendamment de sa détection locale
de détresse. Cette heuristique ne remplace pas une évaluation professionnelle.
Les séances de méditation utilisent des consignes écrites et ne fournissent
pas de piste audio enregistrée.

Le français est la seule langue déclarée. Les notifications push sont annoncées
indisponibles. Le renouvellement automatique des access tokens et les évolutions
d’activation email restent hors périmètre ; un 401 de la session courante la
ferme localement.

Voir [l’architecture](architecture.md) pour les contrats de session et de
persistance, [la méditation](meditation.md) et [la personnalisation](mascot-accessories.md)
pour leurs spécifications détaillées, ainsi que [la livraison](release.md)
pour la configuration des services nécessaires aux parcours distants.
