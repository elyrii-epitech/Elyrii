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
| Jardin | Défis à réaliser, gestes d’aujourd’hui, jardins mensuels et défis terminés du mois | Défis de l’API classés par date de complétion ; gestes locaux en consultation seule |
| Parcours | Choix volontaire, étapes ordonnées, pause/reprise et accès secondaire aux défis existants | Catalogue éditorial local ; progression chiffrée par compte sur cet appareil, sans nouvelle API ni synchronisation entre appareils |
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

Parcours remplace Coach dans la navigation, à la route `/parcours`.
Le choix d’un parcours et la réalisation d’une étape sont explicites.
Le remplacement d’un parcours demande confirmation ; l’annulation conserve
sa position. La pause n’entraîne ni échéance ni pénalité. La progression
reste locale, y compris dans la session de démo isolée. Elle accompagne
l’export des données et la purge locale du compte.
Les défis actifs, propositions à accepter ou refuser et idées disponibles
apparaissent en premier dans le Jardin, et restent accessibles depuis **Mes défis**
dans Parcours. Les catalogues se déplient sans masquer le jardin mensuel.
Seuls les défis réellement terminés produisent les fleurs.
Une étape de Parcours n’en crée pas.

Le Jardin affiche **Défis à réaliser**, puis **Aujourd’hui** et le jardin du mois.
Les prochaines récompenses et la complétion quotidienne n’y figurent plus.
Les flèches permettent de consulter les jardins précédents et de revenir au mois
courant, sans aller dans le futur. Chaque jardin contient une fleur par défi
terminé pendant ce mois, selon `completedAt` converti en date civile locale.
Les doublons sont éliminés par identifiant. Les défis sans date de complétion
ne sont pas attribués arbitrairement à un mois et une note signale leur nombre.

Le paysage et les fleurs varient selon le mois. Les jardins denses se parcourent
horizontalement, sans limite de trente fleurs. Toucher une fleur ouvre le titre
du défi et sa date de réalisation. La liste sous le jardin présente les mêmes
défis, avec trois entrées au départ et une commande pour tout afficher.
Une nouvelle fleur pousse lorsqu’un défi terminé apparaît à la synchronisation,
sans déplacer les fleurs déjà présentes. Consulter un ancien mois ne rejoue pas
cette croissance. Le mouvement réduit présente immédiatement les fleurs matures.
Les défis sont synchronisés à l’ouverture de l’onglet et par glissement vers le bas.
Les gestes locaux d’aujourd’hui ne créent pas de fleurs et ne valident pas de défi.

Le Journal utilise une couleur prune, sans halo ni verre dans les cartes.
La recherche porte sur les entrées chargées et indique cette limite quand
l’historique contient d’autres pages. L’export texte charge l’historique et
inclut les brouillons locaux. Le même éditeur à sauvegarde automatique s’ouvre
depuis le Journal, l’Accueil et les étapes de Parcours. Les outils de dictée,
photo et mot-clé ne sont pas proposés sans service réel. Ouvrir ou fermer
l’éditeur ne valide pas automatiquement une étape.

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
