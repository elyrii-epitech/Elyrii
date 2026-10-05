# Atelier Elyrii — personnalisation et collection

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

L’onglet Collection affiche les portraits des vraies pièces, leurs descriptions,
les paliers et la progression. Les filtres Tous, Tête, Visage, Cou, Dos et
Disponibles facilitent la composition. Le prochain palier indique combien de
défis restent à terminer et propose d’essayer la récompense sur l’ourson.
L’essai d’une pièce verrouillée est temporaire et ne rejoint jamais la tenue
enregistrée. Une célébration regroupe les nouveaux déblocages et respecte la
préférence système de réduction des animations.

`MascotProvider` vérifie les nouveaux équipements lors de l’enregistrement.
Une pièce déjà portée et restaurée reste retirable même si la progression est
indisponible. Cette vérification reste côté client ; le serveur n’ajoute pas
de système d’inventaire. Les paliers existants sont conservés.

## Studio et sauvegarde

L’aperçu 3D reste visible pendant la navigation entre Style, Couleurs et
Collection. Il permet la rotation tactile et les vues Face, 3/4 et Dos.
Sur grand écran, l’aperçu et les réglages occupent deux colonnes. Sur mobile,
les réglages défilent sous l’aperçu ; le clavier laisse la place à la saisie.

Huit palettes servent de base : Elyrii Originel, Astral, Esprit Zen, Sakura
Céleste, Automne Cuivré, Panda Mystique, Noël et Océan. Leurs nuanciers montrent
les couleurs réellement appliquées. Le corps, les détails clairs, les oreilles
et joues, les yeux et les accessoires possèdent ensuite leurs propres couleurs : nuancier, teinte,
saturation, luminosité et code hexadécimal. Les finitions Velours, Satin et
Porcelaine ajustent les matériaux. Les touches dorées et les montures prune
des accessoires conservent leur contraste.

Les changements forment un brouillon avec annulation et retour au look
d’origine. Le bouton Enregistrer applique la tenue à la mascotte globale.
Un glissement de curseur correspond à une seule action d’annulation, avec
recoloration pendant le réglage.
Quitter avec des changements propose de poursuivre, d’enregistrer ou de
quitter sans enregistrer.

La sauvegarde locale utilise `elyrii_mascot_theme_<userId>`,
`elyrii_mascot_customization_<userId>` et `elyrii_mascot_appearance_<userId>`.
La démo et le visiteur ont leurs propres suffixes `demo` et `guest`. Une session
restaurée peut migrer les anciennes clés globales une seule fois ;
`elyrii_mascot_legacy_owner` empêche un autre compte d’en hériter. Les anciens
identifiants d’accessoires de Lucas sont normalisés sans perdre la tenue.
Un cache de son studio local est synchronisé avant de lire un éventuel look
serveur par défaut ; `elyrii_mascot_schema_version_<userId>` marque cette migration.
Les célébrations déjà vues sont également conservées par compte.
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
compte. Le mode démo débloque toute la collection localement, sans requête de
mascotte, défis ou dashboard au serveur, et sans modifier la progression réelle.

## Intégration du travail de Lucas

Source : `origin/feature/lucas-debize/mascott-customisation-color-accessory`,
commits `cdc5ece` et `37bd94d`, relus au tip `1b6e6c2`. L’intégration reprend
les Esprits, l’isolation des préférences, les indicateurs de zones équipées et
trois modèles distinctifs : diplômé, laurier et éclat lumineux. Les accessoires
équivalents retrouvent les pièces du catalogue via des alias. L’éclat est réduit
et déplacé sur la joue pour préserver le regard ; le laurier est simplifié
pour le budget mobile, avec des normales adaptées aux feuilles aplaties.

Le studio conserve ses brouillons, l’annulation, les couleurs libres, les
finitions, l’aperçu persistant et les tenues multizones. Le rendu utilise l’API
publique de model-viewer et un seul modèle animé. Les modifications de ports,
Docker, chat et autres changements de la branche du collègue sont hors de cette
intégration.

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
est présente dans le modèle assemblé. Le rendu web utilise le même script
model-viewer embarqué que les plateformes natives.
Le studio maintient un seuil de résolution de 75 % via l’API publique
`minimumRenderScale` ; le seuil précédent est rétabli à la sortie. L’adaptation
automatique reste disponible au-dessus de ce seuil pour les appareils plus lents.

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

Une entrée dédiée permet de vérifier les widgets de production sans compte :

```sh
cd elyrii_app
flutter run -d chrome -t tool/preview_mascot_studio.dart
# --dart-define=PREVIEW_CHALLENGES=36 déverrouille la collection pour la revue.
```

Les tests `mascot_wardrobe_asset_test.dart` relient chaque identifiant et tenue
au catalogue, vérifient les ancrages animés, matériaux masqués, skins, clips et
budgets. Les tests du provider et de la page couvrent les brouillons, couleurs,
quatre zones, filtres, essais verrouillés, sauvegarde, restauration hors ligne
et ordre des synchronisations. Les tests de session vérifient la migration des
identifiants de Lucas, l’isolation des comptes et de la démo, les réponses
réseau tardives, les écritures invalidées et le refus d’un ancien brouillon.
Le test widget du rendu vérifie la conservation
de la scène. Les écrans compacts avec texte agrandi et les célébrations sans
animation sont vérifiés en thèmes clair et sombre.
Les filtres de zones conservent leur nom accessible lorsqu’un indicateur de
pièce équipée est visible.
