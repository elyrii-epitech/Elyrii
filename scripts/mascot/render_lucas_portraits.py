"""Render the imported pieces with the same bear and lighting as the studio.
Run: blender --background --python scripts/mascot/render_lucas_portraits.py
"""
import importlib.util
import json
from pathlib import Path
import struct

import bpy
from mathutils import Matrix, Quaternion, Vector

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('portrait_helpers', Path(__file__).with_name('build_accessories.py'))
helpers = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helpers)
source = ROOT / 'elyrii_app/assets/optimized/mascot.glb'
raw = source.read_bytes()
length = struct.unpack_from('<I', raw, 12)[0]
document = json.loads(raw[20:20 + length])
nodes = document['nodes']
parents = {child: index for index, node in enumerate(nodes) for child in node.get('children', [])}


def world(index):
    node = nodes[index]
    if 'matrix' in node:
        matrix = Matrix([[node['matrix'][col * 4 + row] for col in range(4)] for row in range(4)])
    else:
        rotation = node.get('rotation', [0, 0, 0, 1])
        matrix = Matrix.Translation(Vector(node.get('translation', [0, 0, 0])))
        matrix @= Quaternion((rotation[3], *rotation[:3])).to_matrix().to_4x4()
        matrix @= Matrix.Diagonal(Vector([*node.get('scale', [1, 1, 1]), 1]))
    return world(parents[index]) @ matrix if index in parents else matrix


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    bpy.context.scene.frame_set(0)
    helpers.preview_scene()
    # Some headless Blender builds omit OpenImageDenoise.
    bpy.context.scene.cycles.use_denoising = False
    bpy.context.scene.cycles.samples = 64
    bpy.context.scene.camera = bpy.data.objects['Accessory portrait']
    output = ROOT / 'elyrii_app/assets/accessory_portraits'
    output.mkdir(parents=True, exist_ok=True)
    basis = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    catalog = json.loads((ROOT / 'scripts/mascot/accessories.json').read_text())['accessories']
    for piece in catalog:
        if 'controlLocalTranslation' not in piece:
            continue
        index = next(i for i, node in enumerate(nodes) if node.get('name') == piece['parent'])
        transform = basis @ world(index) @ Matrix.Translation(Vector(piece['controlLocalTranslation'])) @ basis.inverted()
        before = set(bpy.context.scene.objects)
        bpy.ops.import_scene.gltf(filepath=str(ROOT / 'elyrii_app' / piece['asset']))
        imported = set(bpy.context.scene.objects) - before
        for obj in imported:
            if obj.parent not in imported:
                obj.matrix_world = transform @ obj.matrix_world
        bpy.context.scene.render.filepath = str(output / f"{piece['id']}.png")
        bpy.ops.render.render(write_still=True)
        for obj in imported:
            obj.hide_render = True
        print('Portrait:', piece['id'], flush=True)


if __name__ == '__main__':
    main()
