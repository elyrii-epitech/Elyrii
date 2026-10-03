// npm ci && npm run build. Originals are retained outside the runtime bundle.
import {NodeIO} from '@gltf-transform/core';
import {ALL_EXTENSIONS} from '@gltf-transform/extensions';
import {dequantize, weld, simplify, dedup, prune, resample} from '@gltf-transform/functions';
import {MeshoptSimplifier} from 'meshoptimizer';
import {fileURLToPath} from 'node:url';
import {mkdir, stat} from 'node:fs/promises';

const assets = fileURLToPath(new URL('../../assets/', import.meta.url));
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
await MeshoptSimplifier.ready;
const body = await io.read(`${assets}/elyrii_velours_animations.glb`);
// Conservative error limits protect silhouette, facial features and rig weights.
await body.transform(dequantize(), weld(), simplify({simplifier: MeshoptSimplifier, ratio: 0.35, error: 0.001}), resample(), dedup(), prune());
await mkdir(`${assets}/optimized`, {recursive: true});
const stats = async (doc, name) => {
  const triangles = doc.getRoot().listMeshes().flatMap(m=>m.listPrimitives()).reduce((n,p)=>n+(p.getIndices()?.getCount() ?? p.getAttribute('POSITION').getCount())/3, 0);
  const animations = doc.getRoot().listAnimations().map(a=>a.getName());
  await io.write(`${assets}/optimized/${name}.glb`, doc);
  console.log(JSON.stringify({name, triangles, bytes:(await stat(`${assets}/optimized/${name}.glb`)).size, animations}));
};
await stats(body, 'mascot');
