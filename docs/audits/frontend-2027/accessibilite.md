# Dossier d’accessibilité approfondi

Évaluation et corrections du 10 octobre 2026, application Elyrii iOS/Android,
branche `frontend`, base `4b90d68ff8c09fd9e357f40ed78e5422bb80aa18`.
Ce dossier accompagne le [bilan des corrections](implementation.md).

## Cible et niveau de preuve

La cible technique est **WCAG 2.2 niveau AA**, en tenant compte des interfaces
natives. Le RGAA 4.1.2 est utilisé comme guide pour structurer les questions
sur les images, contrastes, formulaires, scripts et navigation ; il s’applique
au web et ne suffit pas seul à qualifier une application native. Pour un
marché exigeant EN 301 549, les exigences relatives aux logiciels et aux
technologies d’assistance doivent aussi être évaluées dans leur version
contractuelle. [WCAG 2.2](https://www.w3.org/TR/WCAG22/),
[WCAG2ICT](https://www.w3.org/TR/wcag2ict/) et
[RGAA](https://accessibilite.numerique.gouv.fr/methode/) sont les références.

Les tests ci-dessous constituent des preuves ciblées et reproductibles. Ils
ne couvrent pas tous les contenus, états réseau, réglages d’OS ni composants
natifs. Aucun résultat TalkBack, VoiceOver, Switch Control ou lecteur de la
WebView 3D n’est déclaré sans exécution sur la plateforme concernée.

## Mesures automatisées

Les polices Poppins Regular/Medium/SemiBold/Bold et les polices d’icônes sont
chargées réellement. Les captures utilisent des fixtures françaises et une
session de démonstration ; la WebView 3D et les plugins natifs sont remplacés
par leurs adaptateurs de test.

Les 15 écrans sont : connexion, inscription, récupération de mot de passe,
dashboard, défis, journal, chat, coach, méditation, mascotte, paramètres, bilan,
configuration du profil, modification du profil et choix d’avatar.

| Configuration | Taille en points logiques | Facteur de texte | Thème |
| --- | --- | --- | --- |
| Mobile | 390 × 844 | 100 % | Clair |
| Petit écran / très grand texte | 320 × 568 | 300 % | Clair |
| Paysage | 568 × 320 | 200 % | Clair |
| Très étroit | 280 × 568 | 200 % | Clair |
| Petit écran | 320 × 568 | 200 % | Clair |
| Sombre / grand texte | 390 × 844 | 200 % | Sombre |
| Tablette paysage | 1024 × 768 | 100 % | Clair |

**105 rendus** sont enregistrés, et chaque exception Flutter fait échouer le
test. Aucun débordement n’est ignoré pour obtenir un résultat vert. Ce facteur
linéaire de texte ne remplace pas les réglages non linéaires des OS ; le
clavier logiciel affiché et le grand texte simultanés restent à tester sur
appareil. La réussite d’un rendu n’établit pas à elle seule que chaque contrôle
est atteignable : les interactions et les parcours manuels complètent ce test.

La matrice sémantique couvre **60 états** : 15 écrans × 2 thèmes × haut et bas
après défilement. Chaque état est évalué sur le nom des cibles tactiles,
la taille Android 48 × 48, la taille iOS 44 × 44 et le contraste du texte rendu,
soit **240 résultats**. Les surfaces d’action communes ont été portées à
48 × 48 minimum dans les deux systèmes. Le seuil WCAG 2.5.8, les exceptions
et la géométrie native doivent néanmoins être évalués dans leur contexte.

Le SDK Flutter 3.47 compare, dans son helper de taille, certaines limites
transformées d’un enfant avec le rectangle local du parent défilant. Une
translation SafeArea peut alors faire considérer à tort une cible partiellement
coupée comme entièrement visible et trop petite. Les 30 états du haut utilisent
les helpers standards. Pour les 30 états du bas, seul le calcul d’exclusion des
cibles coupées aux limites du scroll est corrigé dans l’espace de coordonnées
du parent ; l’évaluation de taille d’une cible entièrement visible reste celle
du SDK. Un test négatif avec une cible **44 × 44 entièrement visible** sous
SafeArea démontre que le contrôle Android continue de la refuser. Les helpers
de nom et de contraste restent ceux du SDK dans tous les états.

Preuves : [rendus](preuves-implementation/layout.json),
[sémantique](preuves-implementation/semantics.json),
[exécutions et empreintes](preuves-implementation/verification.json).

## Corrections apportées aux composants

| Sujet | Comportement désormais attendu | Preuve automatisée |
| --- | --- | --- |
| Formulaires | Label persistant, hint distinct, erreur rattachée, email et mot de passe proposés au gestionnaire, afficher/masquer annoncé, collage autorisé. | Tests des propriétés autofill, du nom sémantique, de l’erreur et du toggle ; rendus à 300 %. |
| Actions | Nom, rôle, état actif/sélectionné et chargement exposés ; Enter/Espace déclenchent l’action ; action désactivée inopérante ; métadonnées et sous-actions des cartes conservées. | Tests clavier et arbre sémantique, y compris une sous-action de signalement. |
| Focus | Deux anneaux contrastés rendent le focus visible sur les cartes et boutons personnalisés. | Inspection des styles par test et activation clavier ; contraste sur toutes les surfaces natives à confirmer manuellement. |
| Contrastes | Encre de statut adaptée au thème, bordures identifiables, boutons remplis opaques, aucune baisse d’opacité du texte pendant l’appui. | Contraste raster sur les états visibles et ratios de palette ≥ 4,5:1 sur fonds de page/carte dans les deux thèmes ; les limites non textuelles exigent normalement ≥ 3:1. |
| Agrandissement | Titres et textes gardent la taille demandée, colonnes se réorganisent, en-tête peut défiler, dialogues défilent avec leurs actions, édition de mascotte reste atteignable. | 105 rendus ; dialogue long à 300 % ; alternatives de graphique et signalement IA à 300 %. |
| Navigation | Cibles nommées et état sélectionné ; menu natif contenant les six destinations en largeur réduite ou au-delà de 150 % de texte. | Test d’accès tactile aux six destinations à 300 %, ouverture clavier et fermeture Escape ; tests de navigation au format normal. |
| Graphiques | Données d’humeur consultables dans une alternative textuelle dépliable ; répartition et activité exposent valeurs et contexte. | Test d’un graphique non vide, lecture exacte date/quantité, ouverture à 300 % sans erreur ; ne dépend pas seulement de la couleur. |
| Choix et options | Checkbox, switch, radios et segments natifs conservent leur état sémantique. | Tests de sélection, nom des cibles et taille ; signalement avec motif choisi et accusé de réception annoncé. |
| Dialogues | Titre et route annoncés, focus demandé, actions lisibles et défilantes, fermeture Escape, animations retirées si demandé. | Test d’un dialogue long à 300 % avec fermeture clavier ; restitution du focus au lecteur d’écran reste à contrôler. |
| Mouvements | Animations décoratives désactivées ou raccourcies selon les préférences ; focus n’impose pas de changement d’écran. | Tests de réduction du mouvement existants et régressions des composants ; WebGL natif à vérifier. |

Les tailles en points logiques correspondent aux coordonnées Flutter, pas au
nombre de pixels du fichier PNG. Les données de contraste raster sont des
mesures sur les contenus effectivement visibles de la fixture : elles ne
couvrent pas automatiquement tous les avatars, photos, états vides/erreurs et
couleurs qu’un utilisateur peut produire.

## Traçabilité des critères

« Partiel automatisé » signifie qu’une partie du critère est démontrée ; la
colonne manuelle reste à exécuter. Un critère non applicable doit être justifié
sur le contenu effectivement livré, et non présumé absent.

| Critère WCAG | Preuve / changement | Validation restante |
| --- | --- | --- |
| 1.1.1 Contenu non textuel | Icônes d’action nommées, images décoratives exclues, données de graphiques proposées en texte. | Photos de profil, mascotte 3D, tous les états de ressources et affordances natives. |
| 1.2.1 à 1.2.5 Médias | À apprécier sur le catalogue de méditation et les médias réellement distribués. | Inventorier audio/vidéo, équivalents textuels, sous-titres et audiodescription selon le type de média ; ne pas déclarer le critère conforme à partir des widgets. |
| 1.3.1 / 1.3.2 Relations et ordre | Champs natifs, titres sémantiques, valeurs de cartes préservées, graphiques lisibles. | Ordre de lecture complet TalkBack/VoiceOver, ordre après reflow, listes et composants WebView. |
| 1.3.5 Finalité des champs | Hints autofill sur les champs d’identité et de mot de passe. | Remplissage réel avec gestionnaires de mots de passe iOS/Android. |
| 1.4.1 Couleur | Texte des états, quantité et pourcentage des humeurs, alternative textuelle. | Vérifier qu’aucun état fonctionnel n’est transmis uniquement par la couleur, y compris les données utilisateur. |
| 1.4.3 / 1.4.11 Contrastes | Texte normal ≥ 4,5:1, grand texte selon helper SDK ; bordures et focus renforcés. | Mesurer photos/arrière-plans variables, états pressé/erreur/focus sur appareils et verre rendu nativement. |
| 1.4.4 / 1.4.10 Agrandissement et reflow | Matrice jusqu’à 300 %, petit écran, paysage et navigation adaptée. | Texte non linéaire de l’OS, clavier ouvert, écran partagé et modal native. |
| 2.1.1 / 2.1.2 Clavier | Enter/Espace, contrôles natifs, fermeture Escape. | Parcours complet Tab/Shift-Tab et absence de piège dans WebView, galerie/recadrage et lecteur de méditation. |
| 2.2.1 Délais | Pas de nouveau délai d’interaction imposé par ces corrections. | Examiner les délais existants ; la session de 15 min reste inchangée à la demande de l’utilisateur, sans conclusion de conformité sur ce point. |
| 2.3.1 Flashs | Pas de nouveau clignotement ajouté. | Examiner animations et contenus de toutes les séances ; absence de flashs dangereux à confirmer. |
| 2.4.3 / 2.4.6 Ordre, titres et labels | En-têtes explicites, labels natifs, destinations nommées. | Ordre effectif au clavier et au lecteur d’écran, arrivée sur une nouvelle route. |
| 2.4.7 / 2.4.11 Focus visible/non masqué | Anneaux et en-tête défilant, zones sûres prises en compte. | Focus non masqué par le dock, clavier, bannières et sheets dans chaque parcours réel. |
| 2.5.1 / 2.5.7 Gestes / glissement | Actions principales disponibles par contrôles nommés. | Alternatives aux gestes de manipulation 3D, slider, recadrage et éventuels drag-and-drop natifs. |
| 2.5.3 / 2.5.8 Nom et taille des cibles | Labels cohérents et cibles communes ≥ 48 ; contrôles SDK sur 60 états. | Commande vocale avec le texte visible, espacement et géométrie dans les composants natifs. |
| 3.1.1 Langue | Français seul déclaré dans Flutter ; dates et textes français. | Langue effectivement transmise aux lecteurs d’écran et composants système selon la langue du téléphone. |
| 3.2.1 / 3.2.2 Comportements prévisibles | Focus sans activation implicite ; contrôles déclenchés explicitement. | Changements de contexte à la sélection et navigation arrière sur appareils. |
| 3.3.1 / 3.3.2 Erreurs et instructions | Erreurs rattachées, labels persistants, état de sauvegarde exact. | Lecture automatique des erreurs, déplacement de focus vers le champ concerné et reprise sans perte. |
| 3.3.8 Authentification accessible | Collage et autofill autorisés, aucun nouveau puzzle ajouté ; récupération avec code copiable. | Vérifier gestionnaires, saisie vocale et code collé réellement. Activation et refresh exclus du chantier. |
| 4.1.2 / 4.1.3 Noms/états/messages | Native controls, chargement et accusé IA exposés, statut en live region. | Annonce réelle, priorité et absence de répétitions intempestives sur TalkBack/VoiceOver. |

La réduction des animations (notamment WCAG 2.3.3, niveau AAA) améliore
l’expérience au-delà de la seule cible AA. Elle ne justifie pas une déclaration
globale de conformité AAA.

## Parcours concret pour l’évaluation

Utiliser un compte de staging et des données fictives. Tester au minimum un
iPhone avec VoiceOver et un Android avec TalkBack, en thèmes clair/sombre,
à taille de texte maximale, en portrait puis paysage. Noter modèle, version
OS/app/build, options d’accessibilité, résultat, capture ou enregistrement et
numéro d’anomalie. **Ces essais natifs n’ont pas été exécutés dans cet
environnement Linux.**

| Parcours | Manipulation | Résultat attendu | État natif |
| --- | --- | --- | --- |
| Connexion / erreurs | Parcourir tous les champs, soumettre vide, corriger ; afficher/masquer le mot de passe ; autofill et collage. | Nom et rôle distincts, erreur liée au bon champ, état de visibilité annoncé, aucune perte de saisie, actions atteignables avec le clavier ouvert. | Non exécuté |
| Inscription | Lire les consignes longues au grand texte, cocher/décocher l’acceptation et naviguer en arrière. | Aucun texte fonctionnel tronqué ; case annoncée cochée/non cochée ; pas de piège de focus. Les documents restent reportés avec F01. | Non exécuté |
| Récupération | Demander un code, lire l’état, coller un code invalide puis valide de staging. | Message annoncé, erreur compréhensible, collage possible ; indisponibilité honnête sans service mail configuré. | Non exécuté |
| Navigation | Accéder aux six destinations au grand texte, puis Tab/Shift-Tab, Enter, Espace et Escape avec clavier matériel. | Destination et sélection annoncées, cible visible, ordre stable, focus toujours localisable et non masqué. | Non exécuté |
| Journal | Créer, modifier, filtrer, charger une page et enregistrer hors ligne avec retour en ligne. | État de sauvegarde exact et lisible ; erreurs annoncées sans disparition de la note ; pagination utilisable ; dates locales. | Non exécuté |
| Chat / sécurité | Écrire, provoquer une réponse de staging, signaler un motif, ouvrir l’aide ; simuler échec et reprise. | Assistant identifié IA, réponse et bouton de signalement distincts, radios annoncées, accusé lisible, aide accessible même sans détection. | Non exécuté |
| Bilan | Choisir 7/30/90 jours ; ouvrir « Données du graphique des humeurs ». | Période sélectionnée annoncée ; dates et valeurs exactes accessibles sans interpréter les couleurs ou survoler le graphique. | Non exécuté |
| Modales | Ouvrir puis fermer un dialogue long et une sheet avec lecteur d’écran et clavier. | Focus à l’intérieur, fond non activable, actions atteignables à 300 %, retour au déclencheur après fermeture. | Non exécuté |
| Mascotte / avatar | Personnaliser par contrôles, sélectionner une photo, recadrer ; simuler la destruction Android pendant le picker. | Tous les changements disposent d’un contrôle compréhensible ; la manipulation gestuelle possède une alternative lorsqu’exigée ; aucune photo affectée à un autre compte. | Non exécuté |
| Méditation / médias | Choisir, démarrer, mettre en pause, reprendre, terminer et revenir avec l’aide technique. | Contrôles nommés et états annoncés ; contenu média et équivalent accessible appropriés ; pas de focus bloqué ni timer non ajustable non justifié. | Non exécuté |
| Export | Lire le consentement, annuler, exporter et naviguer dans la feuille native de partage. | Avertissement lu avant partage, destinations natives accessibles, annulation sans erreur ni déplacement de focus incohérent. | Non exécuté |

Compléter avec Android Accessibility Scanner, Accessibility Inspector iOS,
Switch Access/Control, commande vocale, texte en gras, contraste accru,
réduction de transparence, animations réduites et police non linéaire. Un
scanner ne remplace pas le parcours au lecteur d’écran. Toute anomalie
bloquant une action ou la lecture d’une erreur doit être corrigée puis rejouée
avant d’annoncer la conformité sur le parcours concerné.

## Rejouer les preuves automatisées

Depuis `elyrii_app`, après la résolution verrouillée :

```bash
flutter test --no-pub test/frontend/accessibility_matrix_test.dart \
  test/frontend/semantics_matrix_test.dart \
  test/frontend/accessibility_interactions_test.dart \
  --dart-define=AUDIT_OUTPUT=build/a11y-evidence
flutter test --no-pub test/core/widgets/glass_navigation_bar_test.dart
```

Le workflow frontend exécute la suite entière et conserve les JSON et PNG.
La conservation CI est de 30 jours ; les captures datées et les résultats
validés destinés à la soutenance doivent être archivés au-delà de cette durée.
