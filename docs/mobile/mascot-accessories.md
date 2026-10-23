# Tenue d'Elyrii et collection

La collection part du véritable ourson 3D : tête ronde très volumineuse, grandes
oreilles roses, yeux prune, museau et ventre blancs, matière crème mate. Les
pièces gardent des volumes arrondis et une palette sauge, rose, lavande, crème
et or doux. Les lunettes ouvertes conservent son regard ; seul le masque de
repos couvre volontairement ses yeux. Le petit sac se découvre de dos.

## Collection et progression

Le catalogue partagé `MascotAccessories` définit les noms, catégories et paliers.
Chaque défi terminé compte ; les défis en cours ne débloquent aucune pièce.
Une tenue combine une pièce par zone : Tête, Visage, Cou et Dos. Sélectionner
une autre pièce remplace seulement sa zone ; sélectionner la pièce portée la
retire. Les quinze pièces permettent 320 tenues, ourson sans accessoire compris.

| Pièce | Identifiant | Défis terminés |
|---|---|---:|
| Chapeau de diplômé | `graduate_cap` | 1 |
| Béret sauge | `beret` | 2 |
| Bonnet douillet | `beanie` | 3 |
| Couronne de laurier | `laurel_crown` | 3 |
| Éclat céleste | `cheek_sparkle` | 4 |
| Couronne de fleurs | `flower_crown` | 5 |
| Couronne d’étoiles | `star_crown` | 7 |
| Broche lunaire | `moon_pin` | 9 |
| Lunettes rondes | `round_glasses` | 12 |
| Casque pastel | `headphones` | 15 |
| Masque de repos | `sleep_mask` | 18 |
| Écharpe cocon | `cozy_scarf` | 22 |
| Nœud papillon | `bow_tie` | 26 |
| Pendentif feuille | `leaf_pendant` | 30 |
| Petit sac à dos | `mini_backpack` | 36 |

Le dressing s'ouvre depuis **Tenue** dans la capsule de l'Accueil.
L'onglet **Accessoires** filtre les portraits par Tête, Visage, Cou et Dos.
Une pièce verrouillée affiche son palier et explique les défis restants.
Elle ne modifie pas l'aperçu. La progression reste indisponible tant que
les défis n'ont pas été chargés.

`MascotProvider` vérifie les nouveaux équipements lors de l’enregistrement.
Une pièce déjà portée et restaurée reste retirable même si la progression est
indisponible. Cette vérification reste côté client ; le serveur n’ajoute pas
de système d’inventaire. Les paliers existants sont conservés.

## Dressing et sauvegarde

Le dressing partage le même modèle 3D que l'Accueil. Les onglets **Couleurs**,
**Accessoires** et **Décor** défilent sous l'aperçu, qui reste monté.
Une fermeture abandonne le brouillon. **Enregistrer** sauvegarde la tenue,
puis le décor local. Si le décor ne peut pas être écrit, le dressing restaure
la tenue précédente et reste ouvert avec une erreur.

Les huit palettes de `MascotThemes.all` recolorent les matériaux du modèle.
Les finitions Velours, Satin et Porcelaine ajustent leur rendu. Les couleurs
libres d'une tenue existante restent conservées jusqu'au choix d'une palette.
**Revenir au look d'origine** rétablit le modèle par défaut dans le brouillon.

Les décors Arches, Collines et Vagues sont disponibles immédiatement.
Clairière demande dix défis terminés. Collines affiche une aube en thème clair.
`AccueilActivities` chiffre le décor dans un document propre au compte.
Le décor n'est pas transmis au serveur, qui ne connaît pas ce champ.


La sauvegarde locale utilise `elyrii_mascot_theme_<userId>`,
`elyrii_mascot_customization_<userId>` et `elyrii_mascot_appearance_<userId>`.
La démo et le visiteur ont leurs propres suffixes `demo` et `guest`. Une session
restaurée peut migrer les anciennes clés globales une seule fois ;
`elyrii_mascot_legacy_owner` empêche un autre compte d’en hériter. Les anciens
identifiants d’accessoires de Lucas sont normalisés sans perdre la tenue.
Un cache de son studio local est synchronisé avant de lire un éventuel look
serveur par défaut ; `elyrii_mascot_schema_version_<userId>` marque cette migration.
L'ancien écran Atelier et sa route `/mascot-customization` sont supprimés.
Le serveur stocke les couleurs et la finition dans
`personality.customization`, validé par `modules/user/mascot.validation.ts`.
Les autres traits de personnalité sont conservés par la fusion existante.

Les écritures serveur sont séquentielles. En cas d’échec réseau, le look reste
enregistré sur l’appareil ; `elyrii_mascot_pending_sync_<userId>` empêche un ancien état
serveur de le remplacer à la réouverture. L’interface permet de relancer la
synchronisation, également retentée au chargement.

Un changement de session invalide les chargements, brouillons et synchronisations
en attente de l’ancien compte. La progression des défis et les statistiques
du dashboard sont réinitialisées ; le cache du dashboard est aussi isolé par
compte. Le mode démo fournit une progression locale, sans modifier
la progression réelle ni envoyer les choix au serveur.

## Intégration du travail de Lucas

Source : `origin/feature/lucas-debize/mascott-customisation-color-accessory`,
commits `cdc5ece` et `37bd94d`, relus au tip `1b6e6c2`. L’intégration reprend
les Esprits, l’isolation des préférences, les indicateurs de zones équipées et
trois modèles distinctifs : diplômé, laurier et éclat lumineux. Les accessoires
équivalents retrouvent les pièces du catalogue via des alias. L’éclat est réduit
et déplacé sur la joue pour préserver le regard ; le laurier est simplifié
pour le budget mobile, avec des normales adaptées aux feuilles aplaties.

Le dressing conserve les finitions, l'aperçu persistant et les tenues multizones.
Le rendu utilise l'API publique de model-viewer et un seul modèle animé.
Les couleurs libres et l'historique d'annulation de l'ancien Atelier ne font
plus partie des contrôles présentés.

## Modèles et rendu

Les quinze fichiers `assets/accessories/*.glb` sont des pièces autonomes.
`scripts/mascot/build_accessories.py` crée les douze pièces du studio ;
`scripts/mascot/build_lucas_accessories.py` reconstruit les trois pièces adaptées
des modèles de Lucas. Le manifeste
`scripts/mascot/accessories.json` décrit leur ancrage. Ces fichiers de travail
ne sont pas embarqués individuellement dans Flutter.

`tool/mascot/build_wardrobe.mjs` assemble une seule copie du corps optimisé et
les quinze pièces dans `assets/optimized/mascot_wardrobe.glb`. Les coiffes et
accessoires de visage suivent `CTRL_head` ; les pièces du cou et du dos suivent
`CTRL_chest`. Leurs coordonnées globales sont converties dans le repère de leur
parent pour préserver l’ajustement au repos ; les pièces adaptées utilisent
un décalage local explicite de `CTRL_head`. Les deux skins et les seize
animations de la mascotte sont conservés.

La garde-robe assemblée pèse 3 778 356 octets et contient 81 302 triangles,
accessoires masqués compris. La tenue la plus détaillée affiche 69 800 triangles.

Les matériaux des accessoires sont transparents en mode MASK par défaut.
Les 319 variantes `KHR_materials_variants` rétablissent les matériaux des pièces
portées. Leur nom assemble les identifiants dans l’ordre des zones avec `+`,
par exemple `beret+round_glasses+cozy_scarf+mini_backpack`. L’API publique
`variantName` de model-viewer sélectionne la tenue ; `null` revient à l’ourson
nu. La même scène et la même animation continuent pendant les changements.
Voir les
[exemples officiels de model-viewer](https://modelviewer.dev/examples/scenegraph/#variants).

`mascot_material_script.dart` recolore les matériaux via l’API publique du
renderer. Il conserve l’atlas peint, le nez et les reflets du regard ; les joues
et oreilles peuvent être recolorées indépendamment. L’éclat conserve son
émission lumineuse, y compris après une personnalisation de sa couleur.
La conversion RGB linéaire vers sRGB préserve la couleur de l’atlas lors de sa
lecture. Trois textures canvas réutilisables limitent la mémoire pendant les
réglages. La finition ajuste rugosité, relief et clearcoat, dont l’extension
est présente dans le modèle assemblé. L’outil local de revue utilise le même
script model-viewer embarqué que les plateformes natives.
Le dressing de l'Accueil garde la qualité adaptative du viewer partagé.

### Présence pendant le chargement

Un rendu PNG du véritable ourson remplace le disque et le spinner de chargement.
La 3D reste montée derrière cette image et devient visible après application
de la tenue, des matériaux et du cadrage, puis réception d’une image rendue.
Le mouvement commence après le fondu, sans délai arbitraire de stabilisation.

Le cache conserve six images au maximum, dans une limite de 3 Mio.
Sa clé comprend le compte, le modèle, le cadrage et l’apparence résolue.
Chaque image conserve sa pose pour préparer la scène suivante à l’identique.
La suppression du compte purge aussi ses images et invalide les écritures tardives.
Sans image correspondant au look, l’ourson d’origine reste affiché pendant
la préparation. Ce cas ne garantit pas les couleurs et accessoires personnalisés.

`mascot_motion_script.dart` adapte uniquement le mélange des animations du
renderer épinglé `flutter_3d_controller 2.3.0`. Il capture la pose composite
avant de réinitialiser la cible. Les répétitions et interruptions repartent
de cette pose, sans remettre l’horloge globale à zéro.
Les pauses entre gestes restent de 10 à 15 secondes. Les lecteurs hors écran
sont suspendus puis libérés selon la rétention existante.

`scripts/mascot/serve_studio.py` expose `/poster` pour régénérer le PNG,
et `runtime_continuity.js` pour vérifier les transitions dans le moteur livré.
Une modification du modèle ou du rendu impose de régénérer le poster et de
changer la révision de clé dans `MascotPosterStore`.


## Reconstruction et vérification

```sh
blender --background --python scripts/mascot/build_accessories.py
python3 scripts/mascot/build_lucas_accessories.py
cd elyrii_app/tool/mascot
npm ci
npm run build:wardrobe
# npm run build reconstruit également le corps optimisé.
```

Pour produire les portraits et leur planche de comparaison (Pillow pour
l’assemblage de la planche) :

```sh
blender --background --python scripts/mascot/build_accessories.py -- --preview
blender --background --python scripts/mascot/render_lucas_portraits.py
python3 scripts/mascot/render_accessory_contact_sheet.py
```

Pour examiner les pièces de face, trois quarts et dos avec le moteur réellement
utilisé dans l’application :

```sh
python3 scripts/mascot/serve_studio.py
# http://127.0.0.1:8766/wardrobe
```

La démo de l'application permet d'ouvrir le dressing depuis l'Accueil.
L'ancien outil `preview_mascot_studio.dart` est supprimé avec l'Atelier.
Les portraits livrés sont dans `elyrii_app/assets/accessory_portraits/`.
Les images de revue générées dans `scripts/mascot/previews/` restent locales.

`test/dashboard_mood_system_test.dart` couvre l'annulation, l'aperçu et la
sauvegarde de la tenue et du décor. Les tests du provider couvrent la
restauration hors ligne, les sessions et l'ordre des synchronisations.
Les tests des activités locales couvrent le verrou Clairière et la
persistance par compte. Les tests d'assets contrôlent les variantes du modèle.
