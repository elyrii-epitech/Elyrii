// npm run build:wardrobe. Reuses the optimized bear once for every accessory.
import {NodeIO} from '@gltf-transform/core';
import {ALL_EXTENSIONS, KHRMaterialsVariants} from '@gltf-transform/extensions';
import {dedup, mergeDocuments, prune, unpartition} from '@gltf-transform/functions';
import {fileURLToPath} from 'node:url';
import {readFile, stat} from 'node:fs/promises';

const assets = fileURLToPath(new URL('../../assets/', import.meta.url));
const manifestPath = fileURLToPath(new URL('../../../scripts/mascot/accessories.json', import.meta.url));
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const body = await io.read(`${assets}/optimized/mascot.glb`);
const extension = body.createExtension(KHRMaterialsVariants);
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

function attach(document, id, parentName) {
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
  attachment.setMatrix(inverse(parent.getWorldMatrix()));
  for (const node of [...importedScene.listChildren()]) attachment.addChild(node);
  parent.addChild(attachment);
  importedScene.dispose();
  const variant = extension.createVariant(id);
  attachment.traverse(node => {
    const mesh = node.getMesh();
    if (!mesh) return;
    for (const primitive of mesh.listPrimitives()) {
      const material = primitive.getMaterial();
      if (!material) throw new Error(`Missing material in accessory ${id}`);
      primitive.setExtension('KHR_materials_variants', extension.createMappingList()
        .addMapping(extension.createMapping().addVariant(variant).setMaterial(material)));
      primitive.setMaterial(hidden);
    }
  });
}

const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
const accessories = Array.isArray(manifest) ? manifest : manifest.accessories;
if (accessories.length !== 12 || new Set(accessories.map(a => a.id)).size !== accessories.length) {
  throw new Error('Expected exactly twelve unique accessories');
}
for (const accessory of accessories) {
  attach(await io.read(`${assets}/accessories/${accessory.id}.glb`), accessory.id, accessory.parent);
}
// MASK + alpha zero gives a clean bare bear by default. Each active variant
// restores only that piece's original materials; other pieces stay invisible.
await body.transform(unpartition(), dedup(), prune());
const output = `${assets}/optimized/mascot_wardrobe.glb`;
await io.write(output, body);
const triangles = body.getRoot().listMeshes().flatMap(mesh => mesh.listPrimitives())
  .reduce((sum, primitive) => sum + primitive.getIndices().getCount() / 3, 0);
console.log(JSON.stringify({name: 'mascot_wardrobe', variants: extension.listVariants().map(v => v.getName()), triangles, bytes: (await stat(output)).size}));
