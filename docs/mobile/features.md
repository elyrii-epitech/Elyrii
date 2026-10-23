# Fonctionnalités mobiles

Les modules se trouvent dans `elyrii_app/lib/features`. Les données privées
locales sont rattachées au compte ; la démo utilise une session isolée.

| Module | Parcours | Données |
| --- | --- | --- |
| Authentification | Connexion, inscription, récupération du mot de passe, démo, déconnexion | API d’authentification ; credentials dans Keychain/Keystore |
| Profil | Profil personnel, identité, objectif unique et choix d’avatar | API utilisateur ; copies d’images dans le cache privé par compte |
| Dashboard et bilan | Humeur, bilan hebdomadaire, mensuel et trimestriel, raccourcis | Historique serveur pour le journal ; humeurs locales ; séances terminées pour les minutes de calme |
| Journal | Fil des jours, écriture et modification, humeur par entrée, lecture, suppression, recherche locale et export texte | API et SQLite paginés par 100 ; brouillons chiffrés par compte ; question du jour choisie enregistrée localement |
| Chat | Conversations, réponses corrélées, reprise d’envoi, copie et signalement | WebSocket Bearer ; historique SQLite chiffré, pages de 50 |
| Jardin | Défis disponibles/actifs/terminés, propositions IA et badges | API ; fraîcheur de 30 secondes, actualisation explicite et après commande |
| Coach | Conseils, besoins et activités ouvrant le journal, une séance ou le guidage | Catalogue local et sessions du repository coach |
| Méditation | 12 pratiques, durée de 1 à 1 439 minutes, pause/reprise et bilan | Contrôleur monotone et synchronisation des séances avec l’API |
| Mascotte | Couleurs, finitions, 15 accessoires répartis sur quatre zones, sauvegarde explicite | Scène GLB partagée ; préférences et progression par compte |
| Réglages | Apparence sombre, claire ou automatique, haptique, confidentialité, export, diagnostics et suppression du compte | Préférences, version installée, API et partage natif volontaire |

L’arrivée présente Elyrii dans le décor Arches, puis donne accès à la connexion,
à l’inscription et à **Découvrir sans compte**. La découverte traverse quatre
questions courtes avant l’Accueil. Le prénom et l’objectif unique utilisent le
profil existant. La première humeur emprunte le même enregistrement que
l’Accueil. Le décor est conservé localement par compte après la sauvegarde
de la tenue. Le choix d’avatar reste dans le Profil.

L’inscription conserve le consentement obligatoire, les règles de mot de passe
et le message de vérification email. La récupération utilise le code réellement
envoyé par le serveur, puis un nouveau mot de passe de 12 à 128 caractères.
Les boutons Google et Apple ne sont pas affichés car le client n’implémente
pas leur connexion. Les liens légaux signalent que les textes complets ne sont
pas encore publiés. Leur publication reste nécessaire avant une mise en production.

Le chat expose les ressources d’urgence indépendamment de sa détection locale
de détresse. Cette heuristique ne remplace pas une évaluation professionnelle.
Les séances de méditation utilisent des consignes écrites et ne fournissent
pas de piste audio enregistrée.

Le Journal utilise une couleur prune, sans halo ni verre dans les cartes.
La recherche porte sur les entrées chargées et indique cette limite quand
l’historique contient d’autres pages. L’export texte charge l’historique et
inclut les brouillons locaux. Le même éditeur à sauvegarde automatique s’ouvre
depuis le Journal, l’Accueil et le Coach. Les outils de dictée, photo et mot-clé
ne sont pas proposés sans service réel. Aucune entrée n’est envoyée à Elyrii
ou au coach.

L’avatar de l’Accueil ouvre le Profil. **Tenue d’Elyrii** retourne au dressing
de l’Accueil, sans second catalogue. Le choix d’avatar depuis le Profil est
enregistré immédiatement. Le formulaire **Mon profil** conserve son bouton
**Enregistrer**. L’objectif bien-être reste un choix unique parmi les six valeurs
du compte. Vider le nom, l’âge, le genre ou l’objectif ne les efface pas sur le
serveur avec le contrat actuel.

Le bilan affiche uniquement les humeurs connues sur cet appareil. Les mois et
les trimestres sont regroupés en sept périodes. Les minutes de calme proviennent
des séances terminées, sans convertir un nombre de séances en durée.
Si la limite de cent séances tronque la période, le bilan signale les minutes
partielles et laisse inconnues les périodes antérieures à la couverture.
Les points, les pourcentages et les taux de défis ne figurent pas dans le bilan.
La carte **Ce qui t’aide** reste absente sans association suffisante dans les données.

**Mes données** explique les copies locales et donne accès à l’export avec
consentement explicite. La suppression exige le mot de passe et conserve la
purge locale par compte. Les textes actuels des conditions et de la politique
restent accessibles dans les Réglages. La politique décrit encore les points à
documenter, et ne constitue pas un document juridique complet.

Le français est la seule langue déclarée. Les notifications push sont annoncées
indisponibles. Le renouvellement automatique des access tokens et les évolutions
d’activation email restent hors périmètre ; un 401 de la session courante la
ferme localement.

Voir [l’architecture](architecture.md) pour les contrats de session et de
persistance, [la méditation](meditation.md) et [la personnalisation](mascot-accessories.md)
pour leurs spécifications détaillées, ainsi que [la livraison](release.md)
pour la configuration des services nécessaires aux parcours distants.
