// npm ci && npm run build. Originals are retained outside the runtime bundle.
import {NodeIO} from '@gltf-transform/core';
import {ALL_EXTENSIONS} from '@gltf-transform/extensions';
import {dequantize, weld, simplify, dedup, prune, resample, mergeDocuments, unpartition} from '@gltf-transform/functions';
import {MeshoptSimplifier} from 'meshoptimizer';
import {fileURLToPath} from 'node:url';
import {mkdir, stat} from 'node:fs/promises';

const assets = fileURLToPath(new URL('../../assets/', import.meta.url));
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
await MeshoptSimplifier.ready;
const body = await io.read(`${assets}/elyrii_velours_animations.glb`);
const hat = await io.read(`${assets}/custom1.glb`);
// Conservative error limits protect silhouette, facial features and rig weights.
await body.transform(dequantize(), weld(), simplify({simplifier: MeshoptSimplifier, ratio: 0.35, error: 0.001}), resample(), dedup(), prune());
await hat.transform(weld(), simplify({simplifier: MeshoptSimplifier, ratio: 0.1, error: 0.001}), dedup(), prune());
await mkdir(`${assets}/optimized`, {recursive: true});
const stats = async (doc, name) => {
  const triangles = doc.getRoot().listMeshes().flatMap(m=>m.listPrimitives()).reduce((n,p)=>n+(p.getIndices()?.getCount() ?? p.getAttribute('POSITION').getCount())/3, 0);
  const animations = doc.getRoot().listAnimations().map(a=>a.getName());
  await io.write(`${assets}/optimized/${name}.glb`, doc);
  console.log(JSON.stringify({name, triangles, bytes:(await stat(`${assets}/optimized/${name}.glb`)).size, animations}));
};
await stats(body, 'mascot');
// One scene: the hat follows the existing animated head instead of opening
// another WKWebView/WebGL renderer. No private model-viewer scene APIs needed.
const head = body.getRoot().listNodes().find(n=>n.getName()==='CTRL_head');
if (!head) throw new Error('Missing animated head attachment');
const mapping = mergeDocuments(body, hat);
const importedScene = mapping.get(hat.getRoot().getDefaultScene() ?? hat.getRoot().listScenes()[0]);
const attachment = body.createNode('Accessory_custom1').setScale([0.5,0.5,0.5]).setTranslation([0.04,0.65,0.02]);
for (const node of [...importedScene.listChildren()]) attachment.addChild(node);
head.addChild(attachment);
importedScene.dispose();
await body.transform(unpartition(), dedup(), prune());
await stats(body, 'mascot_graduate');
