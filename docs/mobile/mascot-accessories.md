# Velours — accessoires déblocables

La collection part du véritable ourson 3D : tête ronde très volumineuse, grandes
oreilles roses, yeux prune, museau et ventre blancs, matière crème mate. Les
pièces gardent des volumes arrondis et une palette sauge, rose, lavande, crème
et or doux. Les lunettes ouvertes conservent son regard ; seul le masque de
repos couvre volontairement ses yeux. Le petit sac se découvre de dos.

## Collection et progression

Le catalogue partagé `MascotAccessories` définit les noms, catégories et paliers.
Chaque défi terminé compte ; les défis en cours ne débloquent aucune pièce.
Une seule pièce peut être équipée, puis retirée en la sélectionnant à nouveau.

| Pièce | Identifiant | Défis terminés |
|---|---|---:|
| Béret sauge | `beret` | 2 |
| Bonnet douillet | `beanie` | 3 |
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

L’atelier affiche les descriptions, les paliers et la progression, avec les
filtres Tous, Tête, Visage, Cou et Dos. Une célébration regroupe les pièces
nouvellement disponibles. `MascotProvider` vérifie le palier au moment de
l’équipement, normalise les anciennes sélections et conserve les préférences
locales et la synchronisation existante. Cette vérification relève du client ;
elle n’ajoute pas de système d’inventaire au serveur.

## Modèles et rendu

Les douze nouveaux fichiers `assets/accessories/*.glb` sont des pièces autonomes,
créées par `scripts/mascot/build_accessories.py`. Le manifeste
`scripts/mascot/accessories.json` décrit leur ancrage. Ces fichiers de travail
ne sont pas embarqués individuellement dans Flutter.

`tool/mascot/build_wardrobe.mjs` assemble une seule copie du corps optimisé et
les douze pièces dans `assets/optimized/mascot_wardrobe.glb`. Les coiffes et
accessoires de visage suivent `CTRL_head` ; les pièces du cou et du dos suivent
`CTRL_chest`. Leurs coordonnées globales sont converties dans le repère de leur
parent pour préserver l’ajustement au repos. Les deux skins et les seize
animations de la mascotte sont conservés.

La garde-robe assemblée pèse 3 637 176 octets et contient 76 522 triangles,
accessoires masqués compris. Un ourson équipé reste sous 65 000 triangles.

Les matériaux des accessoires sont transparents en mode MASK par défaut.
Chaque variante `KHR_materials_variants`, nommée avec l’identifiant de sa pièce,
rétablit uniquement ses matériaux visibles. L’API publique `variantName` de
model-viewer sélectionne la pièce ; `null` revient à l’ourson nu. La même scène
et la même animation continuent pendant les changements de tenue. Voir les
[exemples officiels de model-viewer](https://modelviewer.dev/examples/scenegraph/#variants).

## Reconstruction et vérification

```sh
blender --background --python scripts/mascot/build_accessories.py
cd elyrii_app/tool/mascot
npm ci
npm run build:wardrobe
# npm run build reconstruit également le corps optimisé.
```

Pour produire les portraits et leur planche de comparaison (Pillow pour
l’assemblage de la planche) :

```sh
blender --background --python scripts/mascot/build_accessories.py -- --preview
python3 scripts/mascot/render_accessory_contact_sheet.py
```

Pour examiner les pièces de face, trois quarts et dos avec le moteur réellement
utilisé dans l’application :

```sh
python3 scripts/mascot/serve_studio.py
# http://127.0.0.1:8766/wardrobe
```

Les tests `mascot_wardrobe_asset_test.dart` relient chaque identifiant du
catalogue à une variante, vérifient les ancrages animés, les matériaux masqués,
les skins, les clips et les budgets. Les tests du provider et de la page
vérifient les verrouillages, les filtres, le remplacement, le retrait et la
sauvegarde. Le test widget du rendu vérifie que les changements conservent
la même scène.

Les thèmes gardent la recoloration du viewer existant, y compris ses
limitations sur iOS. Les accessoires ne disposent pas de recoloration séparée.
