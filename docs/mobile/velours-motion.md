# Velours — direction et bibliothèque de mouvement

La mascotte conserve sa matière, sa géométrie et son identité. Sa personnalité
vient des gestes : anticipation, mouvement principal, petit temps d'arrêt,
retour souple. Les pieds restent fixes ; les coudes et les poignets s'articulent,
les oreilles suivent la tête avec 100 ms de retard et les paupières ferment les
yeux. Aucun flottement ou squash Flutter ne s'ajoute aux gestes du dashboard ou
de l'aperçu de personnalisation.

## Les 16 intentions

| Clip | Durée | Intention et déclenchement |
|---|---:|---|
| `idle` | 12 s | Deux souffles discrets, regards et clignements espacés. Présence de base. |
| `greet` | 3,2 s | Patte levée et salut du poignet. Première arrivée sur l'accueil, une fois par instance de MascotProvider. |
| `attentive` | 6,4 s | Inclinaison et acquiescement. Pendant la saisie d'un message. |
| `thinking` | 4,4 s | Regard en biais. Attente du chatbot après 400 ms ; deux boucles maximum. |
| `celebrate` | 3,4 s | Pattes ouvertes et satisfaction. Aperçu « Bravo » et réussite d'un défi détectée après synchronisation. |
| `breathe` | 2 s normalisées | Pose du buste et des pattes pilotée par la progression de l'exercice. Jamais une boucle de deux secondes pendant une séance. |
| `curious` | 7,2 s | Regarde des deux côtés, penche la tête. Variation de repos et interaction. |
| `cozy` | 8 s | Relâche les épaules et ferme longuement les yeux. Variation de repos et première note de journal enregistrée. |
| `acknowledge` | 2,6 s | Signe de tête. Réponse reçue, humeur neutre, toucher ou conseil du Coach enregistré. |
| `reassure` | 4,8 s | S'approche et ouvre doucement une patte. Humeur difficile ou déconnexion du chat. |
| `delight` | 3,6 s | Deux accents de joie contenus. Humeur positive ou toucher. |
| `nuzzle` | 4 s | Penche la tête vers l'utilisateur, yeux fermés. Appui prolongé sur l'accueil. |
| `proud` | 3,8 s | Se redresse et regarde sa tenue. Changement de thème ou d'accessoire dans l'aperçu. |
| `stretch` | 5,6 s | Étirement asymétrique puis relâchement. Variation de repos. |
| `settle` | 5,2 s | Expiration longue et signe de tête. Entrée dans la méditation et fin de séance. |
| `invite` | 3,4 s | Invitation d'une patte. Aperçu « On y va ? », défi démarré ou proposition acceptée. |

Les gestes sont aussi consultables dans un studio local, sans connexion au
backend ni modification des données utilisateur :

```sh
python3 scripts/mascot/serve_studio.py
# http://127.0.0.1:8766
```

Le studio emploie le moteur installé par `flutter pub get`. Il propose une
chronologie, cinq rythmes respiratoires, pause, mouvement réduit et contrôle
automatique de lecture. Il sert le GLB de l'application, pas une copie.

## Connexion aux parcours

`MascotProvider` expose une petite file de réactions (`react`) partagée par
les onglets persistants. Le dashboard consomme le compteur de déclenchement et
reprend le geste au retour d'un onglet : démarrer ou accepter un défi déclenche
`invite`, une nouvelle réussite déclenche `celebrate`, la première note
enregistrée déclenche `cozy` et un conseil du Coach validé déclenche
`acknowledge`. Une clé d'événement peut dédupliquer les flux réseau ; les
interactions directes restent rejouables.

## Enchaînement et accessibilité

`MascotMotionController` concentre les règles de rythme et d'interruption. Les
écrans transmettent une intention et, pour rejouer le même geste, un compteur
`animationTrigger`. Une notification identique ne redémarre rien. Tout nouveau
contexte annule le timer précédent : une ancienne célébration ne peut pas
interrompre une écoute. Après un geste bref, Velours revient au repos.

Au repos, une variation arrive après 14 à 24 secondes de calme ; deux variations
consécutives diffèrent. Ces gestes ne surviennent ni pendant l'écoute ni
pendant une attente réseau prolongée. Le toucher dispose d'un délai minimal de
1,4 seconde, sans bloquer le changement de message dans la bulle de l'accueil.

Les timers et le lecteur sont suspendus quand `TickerMode` désactive la route
ou que l'application quitte le premier plan. Les gestes devenus périmés ne se
rejouent pas au retour. Avec `MediaQuery.disableAnimations`, le modèle et le
placeholder restent stables. Le statut et le décompte respiratoire sont
toujours transmis par le texte. La visibilité liée au défilement n'est pas
mesurée : une mascotte scrollée hors du viewport reste soumise à sa route.

## Respiration

`ActiveBreathingView` partage son AnimationController avec le viewer via
`breathProgress`. L'inspiration va de 0 à 1, l'expiration de 1 à 0 ; les
rétentions conservent une extrémité. Une pause arrête cette même progression.
La reprise conserve la pose et rejoint la prochaine transition du minuteur.

Le lecteur cherche la pose dans la première seconde du clip `breathe`, qui
contient toutes les amplitudes possibles du souffle. Il envoie au maximum
30 commandes par seconde à la WebView, plus les poses d'extrémité. Un modèle
qui termine son chargement en cours de séance rejoint la progression actuelle.

## Rendu et maintenance

`MascotModelSurface` isole l'accès au moteur interne de
`flutter_3d_controller` **2.3.0**, version épinglée. Le widget public du package
n'expose pas la recherche de pose. Cet adapter utilise le même chargement
d'assets, la même WebView et les mêmes commandes caméra que le package.

Les changements de clip attendent `updateComplete`, réinitialisent le temps
explicitement et annulent les commandes JavaScript périmées. Cela permet de
rejouer un même geste, d'effectuer les fondus et de suspendre une lecture sans
qu'une ancienne promesse ne la relance. Vérifier cet adapter lors d'une mise à
jour du package. Après 12 secondes de chargement sans succès, le PNG de secours
prend le relais.

Les accessoires utilisent encore un viewer séparé et un ancrage à l'écran ;
ils ne sont pas skinnés sur l'os de la tête. Leur viewer reste statique et
l'ajout d'un accessoire ne remonte plus le viewer du corps. L'ancrage rigide des
accessoires et la recoloration sur iOS restent des limites du rendu existant.

## Reconstruire et vérifier

Le script Python n'a aucune dépendance externe. Il remplace les courbes du GLB
riggé existant, compacte les anciennes données et conserve meshes, images,
skins et matériaux. Deux reconstructions donnent exactement le même fichier.

```sh
python3 scripts/mascot/build_velours_motion.py
python3 scripts/mascot/check_velours_motion.py
# Option : comparer la géométrie à une révision git
python3 scripts/mascot/check_velours_motion.py --compare-ref HEAD
cd elyrii_app
flutter analyze
flutter test
```

La bibliothèque contient 2 404 poses échantillonnées à 30 Hz et pèse
5 687 376 octets, soit +248 556 octets (+4,6 %) par rapport aux six clips.
Le contrôle vérifie les nombres finis, quaternions normalisés, limites des
paupières, poses communes aux extrémités et correspondance des durées avec
le catalogue Dart. Le validateur Khronos ne signale aucune erreur ni aucun
avertissement. Le bouton du studio vérifie les 16 lectures, la fin de trois
gestes et une pose respiratoire maintenue.
