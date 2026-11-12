// npm run build:wardrobe. Reuses the optimized bear once for every accessory.
import {NodeIO} from '@gltf-transform/core';
import {ALL_EXTENSIONS, KHRMaterialsVariants, KHRMaterialsClearcoat} from '@gltf-transform/extensions';
import {dedup, mergeDocuments, prune, unpartition} from '@gltf-transform/functions';
import {fileURLToPath} from 'node:url';
import {readFile, stat} from 'node:fs/promises';

const assets = fileURLToPath(new URL('../../assets/', import.meta.url));
const manifestPath = fileURLToPath(new URL('../../../scripts/mascot/accessories.json', import.meta.url));
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const body = await io.read(`${assets}/optimized/mascot.glb`);
const extension = body.createExtension(KHRMaterialsVariants);
const clearcoat = body.createExtension(KHRMaterialsClearcoat);
for (const material of body.getRoot().listMaterials()) {
  // Authored matte appearance remains the default. The studio can adjust the
  // clearcoat through model-viewer's public material API without reloading.
  if (['root.2', 'root.8', 'Velours eyelids'].includes(material.getName())) {
    material.setExtension('KHR_materials_clearcoat', clearcoat.createClearcoat()
      .setClearcoatFactor(0).setClearcoatRoughnessFactor(0.12));
  }
}
const hidden = body.createMaterial('Accessory_hidden')
  .setBaseColorFactor([1, 1, 1, 0]).setAlphaMode('MASK').setAlphaCutoff(0.5);
const controls = new Map(body.getRoot().listNodes().map(node => [node.getName(), node]));

// Column-major glTF matrices. Preserve the authored world-space fit when
// parenting an accessory underneath an animated head or chest control.
function inverse(matrix) {
  const rows = Array.from({length: 4}, (_, row) => [
    ...Array.from({length: 4}, (_, col) => matrix[col * 4 + row]),
    ...Array.from({length: 4}, (_, col) => Number(col === row)),
  ]);
  for (let col = 0; col < 4; col++) {
    const pivot = rows.reduce((best, row, index) =>
      index >= col && Math.abs(row[col]) > Math.abs(rows[best][col]) ? index : best, col);
    [rows[col], rows[pivot]] = [rows[pivot], rows[col]];
    const divisor = rows[col][col];
    if (Math.abs(divisor) < 1e-10) throw new Error('Singular attachment transform');
    rows[col] = rows[col].map(value => value / divisor);
    for (let row = 0; row < 4; row++) {
      if (row === col) continue;
      const factor = rows[row][col];
      rows[row] = rows[row].map((value, i) => value - factor * rows[col][i]);
    }
  }
  return Array.from({length: 16}, (_, i) => rows[i % 4][4 + Math.floor(i / 4)]);
}

const attachedPrimitives = new Map();
function attach(document, id, parentName, localTranslation) {
  const parent = controls.get(parentName);
  if (!parent) throw new Error(`Missing attachment ${parentName}`);
  if (document.getRoot().listAnimations().length || document.getRoot().listSkins().length) {
    throw new Error(`Accessory ${id} must contain static geometry only`);
  }
  const sourceScene = document.getRoot().getDefaultScene() ?? document.getRoot().listScenes()[0];
  if (!sourceScene) throw new Error(`Missing scene in accessory ${id}`);
  const mapping = mergeDocuments(body, document);
  const importedScene = mapping.get(sourceScene);
  const attachment = body.createNode(`Accessory_${id}`).setExtras({accessoryId: id, attachment: parentName});
  if (localTranslation) {
    attachment.setTranslation(localTranslation);
  } else {
    attachment.setMatrix(inverse(parent.getWorldMatrix()));
  }
  for (const node of [...importedScene.listChildren()]) attachment.addChild(node);
  parent.addChild(attachment);
  importedScene.dispose();
  const primitives = [];
  attachment.traverse(node => {
    const mesh = node.getMesh();
    if (!mesh) return;
    for (const primitive of mesh.listPrimitives()) {
      const material = primitive.getMaterial();
      if (!material) throw new Error(`Missing material in accessory ${id}`);
      if (localTranslation) {
        const originalName = material.getName();
        const detail = /Gold|Olives/.test(originalName) ? 'gold'
          : /Wood/.test(originalName) ? 'wood'
          : /Core/.test(originalName) ? 'core' : 'fabric';
        material.setName(`Velours accessory ${id} ${detail}`);
      }
      primitives.push({primitive, material});
      primitive.setMaterial(hidden);
    }
  });
  attachedPrimitives.set(id, primitives);
}

const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
const accessories = Array.isArray(manifest) ? manifest : manifest.accessories;
if (new Set(accessories.map(a => a.id)).size !== accessories.length) {
  throw new Error('Expected unique accessory identifiers');
}
for (const accessory of accessories) {
  attach(await io.read(`${assets}/accessories/${accessory.id}.glb`), accessory.id, accessory.parent, accessory.controlLocalTranslation);
}
// Every one-per-slot outfit is a public glTF variant. Geometry, skins and
// animations are shared, including when four accessories are equipped.
const slots = ['Tête', 'Visage', 'Cou', 'Dos'].map(category =>
  accessories.filter(piece => piece.category === category).map(piece => piece.id));
let outfits = [[]];
for (const slot of slots) {
  outfits = outfits.flatMap(outfit => [outfit, ...slot.map(id => [...outfit, id])]);
}
for (const outfit of outfits.filter(outfit => outfit.length)) {
  const variant = extension.createVariant(outfit.join('+'));
  for (const id of outfit) {
    for (const {primitive, material} of attachedPrimitives.get(id)) {
      let mappings = primitive.getExtension('KHR_materials_variants');
      if (!mappings) {
        mappings = extension.createMappingList();
        primitive.setExtension('KHR_materials_variants', mappings);
      }
      let mapping = mappings.listMappings().find(mapping => mapping.getMaterial() === material);
      if (!mapping) {
        mapping = extension.createMapping().setMaterial(material);
        mappings.addMapping(mapping);
      }
      mapping.addVariant(variant);
    }
  }
}
// MASK + alpha zero gives a clean bare bear by default. Each active variant
// restores only that piece's original materials; other pieces stay invisible.
await body.transform(unpartition(), dedup(), prune());
const output = `${assets}/optimized/mascot_wardrobe.glb`;
await io.write(output, body);
const triangles = body.getRoot().listMeshes().flatMap(mesh => mesh.listPrimitives())
  .reduce((sum, primitive) => sum + primitive.getIndices().getCount() / 3, 0);
console.log(JSON.stringify({name: 'mascot_wardrobe', pieces: accessories.length, variants: extension.listVariants().length, triangles, bytes: (await stat(output)).size}));
