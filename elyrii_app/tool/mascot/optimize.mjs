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
const triangles = body.getRoot().listMeshes().flatMap(m=>m.listPrimitives()).reduce((n,p)=>n+(p.getIndices()?.getCount() ?? p.getAttribute('POSITION').getCount())/3, 0);
const animations = body.getRoot().listAnimations().map(a=>a.getName());
const output = `${assets}/optimized/mascot.glb`;
await io.write(output, body);
console.log(JSON.stringify({name:'mascot', triangles, bytes:(await stat(output)).size, animations}));
