#!/usr/bin/env python3
"""Rebuild the three distinct pieces adapted from Lucas Debize's studio.

Source: feature/lucas-debize/mascott-customisation-color-accessory (37bd94d).
The laurel keeps its authored silhouette with fewer leaf segments for mobile.
Attachment offsets live in accessories.json; the wardrobe builder rigs them.
Run: python3 scripts/mascot/build_lucas_accessories.py
"""
import json
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = ROOT / 'elyrii_app/assets/accessories'

class GLBBuilder:
    def __init__(self):
        self.nodes = []
        self.meshes = []
        self.materials = []
        self.accessors = []
        self.buffer_views = []
        self.binary = bytearray()

    def add_material(self, name, base_color, roughness=0.5, metallic=0.0, emissive=None, double_sided=True):
        mat = {
            'name': name,
            'pbrMetallicRoughness': {
                'baseColorFactor': base_color,
                'roughnessFactor': roughness,
                'metallicFactor': metallic,
            },
            'doubleSided': double_sided,
        }
        if emissive:
            mat['emissiveFactor'] = emissive
        self.materials.append(mat)
        return len(self.materials) - 1

    def _append_buffer(self, data, target=None):
        self.binary.extend(b'\0' * (-len(self.binary) % 4))
        offset = len(self.binary)
        self.binary.extend(data)
        view = {'buffer': 0, 'byteOffset': offset, 'byteLength': len(data)}
        if target:
            view['target'] = target
        self.buffer_views.append(view)
        return len(self.buffer_views) - 1

    def add_mesh_primitive(self, vertices, normals, indices, material_idx):
        min_pos = [min(v[c] for v in vertices) for c in range(3)]
        max_pos = [max(v[c] for v in vertices) for c in range(3)]
        flat_verts = [val for v in vertices for val in v]
        v_bytes = struct.pack(f'<{len(flat_verts)}f', *flat_verts)
        v_view = self._append_buffer(v_bytes, target=34962)

        v_acc = len(self.accessors)
        self.accessors.append({
            'bufferView': v_view,
            'componentType': 5126,
            'count': len(vertices),
            'type': 'VEC3',
            'min': min_pos,
            'max': max_pos,
        })

        flat_norms = [val for n in normals for val in n]
        n_bytes = struct.pack(f'<{len(flat_norms)}f', *flat_norms)
        n_view = self._append_buffer(n_bytes, target=34962)

        n_acc = len(self.accessors)
        self.accessors.append({
            'bufferView': n_view,
            'componentType': 5126,
            'count': len(normals),
            'type': 'VEC3',
        })

        idx_bytes = struct.pack(f'<{len(indices)}H', *indices)
        idx_view = self._append_buffer(idx_bytes, target=34963)

        idx_acc = len(self.accessors)
        self.accessors.append({
            'bufferView': idx_view,
            'componentType': 5123,
            'count': len(indices),
            'type': 'SCALAR',
        })

        mesh = {
            'primitives': [{
                'attributes': {'POSITION': v_acc, 'NORMAL': n_acc},
                'indices': idx_acc,
                'material': material_idx,
            }]
        }
        self.meshes.append(mesh)
        mesh_idx = len(self.meshes) - 1
        self.nodes.append({'mesh': mesh_idx})
        return mesh_idx

    def build_glb_bytes(self):
        doc = {
            'asset': {'version': '2.0', 'generator': 'Elyrii Flawless Studio'},
            'scene': 0,
            'scenes': [{'nodes': list(range(len(self.nodes)))}],
            'nodes': self.nodes,
            'meshes': self.meshes,
            'materials': self.materials,
            'accessors': self.accessors,
            'bufferViews': self.buffer_views,
            'buffers': [{'byteLength': len(self.binary)}],
        }
        encoded = json.dumps(doc, separators=(',', ':')).encode('utf-8')
        encoded += b' ' * (-len(encoded) % 4)
        self.binary.extend(b'\0' * (-len(self.binary) % 4))

        total_len = 28 + len(encoded) + len(self.binary)
        header = struct.pack('<4sII', b'glTF', 2, total_len)
        json_chunk = struct.pack('<I4s', len(encoded), b'JSON') + encoded
        bin_chunk = struct.pack('<I4s', len(self.binary), b'BIN\0') + self.binary
        return header + json_chunk + bin_chunk


def make_torus(ring_r, pipe_r, ring_segs=32, pipe_segs=16, offset=(0, 0, 0), scale=(1, 1, 1), rot_x=0.0):
    verts, norms, indices = [], [], []
    cos_rx, sin_rx = math.cos(rot_x), math.sin(rot_x)
    for i in range(ring_segs):
        theta = 2.0 * math.pi * i / ring_segs
        cos_t, sin_t = math.cos(theta), math.sin(theta)
        for j in range(pipe_segs):
            phi = 2.0 * math.pi * j / pipe_segs
            cos_p, sin_p = math.cos(phi), math.sin(phi)
            cx = (ring_r + pipe_r * cos_p) * cos_t
            cy = pipe_r * sin_p
            cz = (ring_r + pipe_r * cos_p) * sin_t

            cy_rx = cy * cos_rx - cz * sin_rx
            cz_rx = cy * sin_rx + cz * cos_rx

            nx = cos_p * cos_t
            ny = sin_p
            nz = cos_p * sin_t
            ny_rx = ny * cos_rx - nz * sin_rx
            nz_rx = ny * sin_rx + nz * cos_rx

            verts.append((offset[0] + cx * scale[0], offset[1] + cy_rx * scale[1], offset[2] + cz_rx * scale[2]))
            norms.append((nx, ny_rx, nz_rx))

    for i in range(ring_segs):
        i_next = (i + 1) % ring_segs
        for j in range(pipe_segs):
            j_next = (j + 1) % pipe_segs
            i0 = i * pipe_segs + j
            i1 = i_next * pipe_segs + j
            i2 = i_next * pipe_segs + j_next
            i3 = i * pipe_segs + j_next
            indices.extend([i0, i1, i2, i0, i2, i3])
    return verts, norms, indices


def make_cylinder(r_top, r_bot, height, segs=24, offset=(0, 0, 0), scale=(1, 1, 1), rot_x=0.0, rot_z=0.0):
    verts, norms, indices = [], [], []
    half_h = height / 2.0
    cos_x, sin_x = math.cos(rot_x), math.sin(rot_x)
    cos_z, sin_z = math.cos(rot_z), math.sin(rot_z)
    def rotate_pt(x, y, z):
        x1 = x * cos_z - y * sin_z
        y1 = x * sin_z + y * cos_z
        z1 = z
        x2 = x1
        y2 = y1 * cos_x - z1 * sin_x
        z2 = y1 * sin_x + z1 * cos_x
        return (offset[0] + x2 * scale[0], offset[1] + y2 * scale[1], offset[2] + z2 * scale[2])

    for i in range(segs):
        angle = 2.0 * math.pi * i / segs
        ca, sa = math.cos(angle), math.sin(angle)
        bx, by, bz = rotate_pt(r_bot * ca, -half_h, r_bot * sa)
        nx, ny, nz = rotate_pt(ca, 0.0, sa)
        verts.append((bx, by, bz))
        norms.append((nx, ny, nz))
        tx, ty, tz = rotate_pt(r_top * ca, half_h, r_top * sa)
        verts.append((tx, ty, tz))
        norms.append((nx, ny, nz))

    for i in range(segs):
        i_next = (i + 1) % segs
        b0, t0 = i * 2, i * 2 + 1
        b1, t1 = i_next * 2, i_next * 2 + 1
        indices.extend([b0, b1, t0, t0, b1, t1])

    c_bot = len(verts)
    cbx, cby, cbz = rotate_pt(0, -half_h, 0)
    cnxb, cnyb, cnzb = rotate_pt(0, -1, 0)
    verts.append((cbx, cby, cbz))
    norms.append((cnxb, cnyb, cnzb))

    c_top = len(verts)
    ctx, cty, ctz = rotate_pt(0, half_h, 0)
    cnxt, cnyt, cnzt = rotate_pt(0, 1, 0)
    verts.append((ctx, cty, ctz))
    norms.append((cnxt, cnyt, cnzt))

    for i in range(segs):
        i_next = (i + 1) % segs
        b0, b1 = i * 2, i_next * 2
        t0, t1 = i * 2 + 1, i_next * 2 + 1
        indices.extend([c_bot, b1, b0])
        indices.extend([c_top, t0, t1])
    return verts, norms, indices


def make_sphere(radius, rings=16, segs=20, offset=(0, 0, 0), scale=(1, 1, 1)):
    verts, norms, indices = [], [], []
    for r in range(rings + 1):
        phi = math.pi * r / rings
        cp, sp = math.cos(phi), math.sin(phi)
        for s in range(segs):
            theta = 2.0 * math.pi * s / segs
            ct, st = math.cos(theta), math.sin(theta)
            nx, ny, nz = sp * ct, cp, sp * st
            verts.append((offset[0] + radius * nx * scale[0], offset[1] + radius * ny * scale[1], offset[2] + radius * nz * scale[2]))
            normal = (nx / scale[0], ny / scale[1], nz / scale[2])
            length = math.sqrt(sum(component * component for component in normal))
            norms.append(tuple(component / length for component in normal))

    for r in range(rings):
        for s in range(segs):
            s_next = (s + 1) % segs
            i0 = r * segs + s
            i1 = (r + 1) * segs + s
            i2 = (r + 1) * segs + s_next
            i3 = r * segs + s_next
            indices.extend([i0, i1, i2, i0, i2, i3])
    return verts, norms, indices


def make_box(dx, dy, dz, offset=(0, 0, 0), rot_x=0.0, rot_y=0.0, rot_z=0.0):
    hx, hy, hz = dx / 2.0, dy / 2.0, dz / 2.0
    ox, oy, oz = offset
    cos_x, sin_x = math.cos(rot_x), math.sin(rot_x)
    cos_y, sin_y = math.cos(rot_y), math.sin(rot_y)
    cos_z, sin_z = math.cos(rot_z), math.sin(rot_z)
    def rot(pt):
        x, y, z = pt
        y1 = y * cos_x - z * sin_x
        z1 = y * sin_x + z * cos_x
        x2 = x * cos_y + z1 * sin_y
        z2 = -x * sin_y + z1 * cos_y
        x3 = x2 * cos_z - y1 * sin_z
        y3 = x2 * sin_z + y1 * cos_z
        z3 = z2
        return (ox + x3, oy + y3, oz + z3)

    raw_corners = [
        ((-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz), (0, 0, 1)),
        ((hx, -hy, -hz), (-hx, -hy, -hz), (-hx, hy, -hz), (hx, hy, -hz), (0, 0, -1)),
        ((-hx, hy, hz), (hx, hy, hz), (hx, hy, -hz), (-hx, hy, -hz), (0, 1, 0)),
        ((-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz), (0, -1, 0)),
        ((hx, -hy, hz), (hx, -hy, -hz), (hx, hy, -hz), (hx, hy, hz), (1, 0, 0)),
        ((-hx, -hy, -hz), (-hx, -hy, hz), (-hx, hy, hz), (-hx, hy, -hz), (-1, 0, 0)),
    ]
    verts, norms, indices = [], [], []
    for c0, c1, c2, c3, n in raw_corners:
        start = len(verts)
        verts.extend([rot(c0), rot(c1), rot(c2), rot(c3)])
        nx, ny, nz = n
        ny1 = ny * cos_x - nz * sin_x
        nz1 = ny * sin_x + nz * cos_x
        nx2 = nx * cos_y + nz1 * sin_y
        nz2 = -nx * sin_y + nz1 * cos_y
        nx3 = nx2 * cos_z - ny1 * sin_z
        ny3 = nx2 * sin_z + ny1 * cos_z
        nz3 = nz2
        norms.extend([(nx3, ny3, nz3)] * 4)
        indices.extend([start, start + 1, start + 2, start, start + 2, start + 3])
    return verts, norms, indices


def merge_geometries(geom_list):
    out_v, out_n, out_i = [], [], []
    for v, n, i in geom_list:
        offset = len(out_v)
        out_v.extend(v)
        out_n.extend(n)
        out_i.extend(idx + offset for idx in i)
    return out_v, out_n, out_i


def build_custom1():
    builder = GLBBuilder()
    silk_mat = builder.add_material('RoyalMidnightFelt', [0.10, 0.14, 0.26, 1.0], roughness=0.78, metallic=0.0)
    gold_mat = builder.add_material('MajesticGold', [0.98, 0.84, 0.30, 1.0], roughness=0.15, metallic=0.92)

    geoms_silk = []
    # Base skullcap sitting on top of skull
    geoms_silk.append(make_cylinder(0.36, 0.42, 0.20, segs=28, offset=(0.0, 0.08, 0.0)))
    # Imposing mortarboard (1.05 x 1.05) tilted with academic flair
    geoms_silk.append(make_box(1.05, 0.038, 1.05, offset=(0.0, 0.18, 0.0), rot_y=math.radians(45), rot_x=-0.14, rot_z=0.06))

    geoms_gold = []
    # Gold ribbon around cap base
    geoms_gold.append(make_torus(ring_r=0.40, pipe_r=0.016, ring_segs=28, pipe_segs=8, offset=(0.0, -0.01, 0.0)))
    # Center gold button
    geoms_gold.append(make_sphere(0.038, rings=8, segs=8, offset=(0.0, 0.21, 0.0)))
    # Long flowing cord draped over side
    geoms_gold.append(make_cylinder(0.010, 0.010, 0.44, segs=10, offset=(0.38, 0.10, 0.16), scale=(1.0, 1.0, 1.0), rot_x=0.22, rot_z=-0.44))
    # Bushy gold tassel
    geoms_gold.append(make_cylinder(0.035, 0.052, 0.18, segs=16, offset=(0.54, -0.18, 0.26), scale=(1.0, 1.0, 1.0), rot_x=0.12, rot_z=-0.15))
    geoms_gold.append(make_sphere(0.045, rings=8, segs=10, offset=(0.54, -0.07, 0.26)))

    v, n, i = merge_geometries(geoms_silk)
    builder.add_mesh_primitive(v, n, i, silk_mat)
    v, n, i = merge_geometries(geoms_gold)
    builder.add_mesh_primitive(v, n, i, gold_mat)
    return builder.build_glb_bytes()


def build_crown_laurel():
    builder = GLBBuilder()
    leaf_mat = builder.add_material('TrueGreenLaurel', [0.16, 0.60, 0.22, 1.0], roughness=0.40, metallic=0.0)
    stem_mat = builder.add_material('BranchWood', [0.36, 0.25, 0.18, 1.0], roughness=0.65, metallic=0.0)
    berry_mat = builder.add_material('GoldenOlives', [0.98, 0.84, 0.32, 1.0], roughness=0.15, metallic=0.92)

    geoms_stem = []
    geoms_stem.append(make_torus(ring_r=0.55, pipe_r=0.018, ring_segs=24, pipe_segs=6, offset=(0.0, 0.0, 0.0), scale=(0.96, 0.80, 0.98), rot_x=-0.22))

    geoms_leaf = []
    sin_tilt, cos_tilt = math.sin(-0.22), math.cos(-0.22)
    for p in range(20):
        angle = 2.0 * math.pi * p / 20.0
        cx = 0.55 * 0.96 * math.cos(angle)
        cz = 0.55 * 0.98 * math.sin(angle)
        cy = -cz * sin_tilt
        cz_rot = cz * cos_tilt
        geoms_leaf.append(make_sphere(0.065, rings=5, segs=6, offset=(cx + 0.025, cy + 0.045, cz_rot + 0.02), scale=(0.40, 1.35, 0.25)))
        geoms_leaf.append(make_sphere(0.065, rings=5, segs=6, offset=(cx - 0.025, cy + 0.035, cz_rot - 0.02), scale=(0.40, 1.35, 0.25)))

    geoms_berry = []
    for ba in [-40, -20, 0, 20, 40]:
        brad = math.radians(ba)
        bx = 0.55 * 0.96 * math.sin(brad)
        bz = 0.55 * 0.98 * math.cos(brad)
        by = -bz * sin_tilt
        bz_rot = bz * cos_tilt
        geoms_berry.append(make_sphere(0.026, rings=6, segs=6, offset=(bx, by + 0.025, bz_rot + 0.03)))

    v, n, i = merge_geometries(geoms_stem)
    builder.add_mesh_primitive(v, n, i, stem_mat)
    v, n, i = merge_geometries(geoms_leaf)
    builder.add_mesh_primitive(v, n, i, leaf_mat)
    v, n, i = merge_geometries(geoms_berry)
    builder.add_mesh_primitive(v, n, i, berry_mat)
    return builder.build_glb_bytes()


def build_flower_mouth():
    builder = GLBBuilder()
    # Glowing vibrant radiant cyan/sapphire star (emissive pops against warm fur!)
    star_mat = builder.add_material('RadiantCyanGlow', [0.0, 0.92, 1.0, 1.0], roughness=0.05, metallic=0.20, emissive=[0.25, 0.95, 1.0])
    core_mat = builder.add_material('DiamondSparkleCore', [0.98, 1.0, 1.0, 1.0], roughness=0.01, metallic=0.50, emissive=[0.60, 0.90, 1.0])

    geoms_star = []
    # Adapt Lucas's sparkle as a small cheek jewel, keeping the eye visible.
    geoms_star.append(make_sphere(0.055, rings=10, segs=12, offset=(0.40, 0.25, 0.46), scale=(2.2, 0.35, 0.45)))
    geoms_star.append(make_sphere(0.055, rings=10, segs=12, offset=(0.40, 0.25, 0.46), scale=(0.35, 2.2, 0.45)))
    # Diagonal sparkles
    geoms_star.append(make_sphere(0.03, rings=8, segs=8, offset=(0.40, 0.25, 0.46), scale=(1.2, 1.2, 0.4)))

    geoms_core = []
    # Glowing diamond center
    geoms_core.append(make_sphere(0.022, rings=8, segs=10, offset=(0.40, 0.25, 0.478)))

    v, n, i = merge_geometries(geoms_star)
    builder.add_mesh_primitive(v, n, i, star_mat)
    v, n, i = merge_geometries(geoms_core)
    builder.add_mesh_primitive(v, n, i, core_mat)
    return builder.build_glb_bytes()

def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    pieces = {
        'graduate_cap': build_custom1(),
        'laurel_crown': build_crown_laurel(),
        'cheek_sparkle': build_flower_mouth(),
    }
    for name, data in pieces.items():
        (OUTPUT_DIR / f'{name}.glb').write_bytes(data)
        print(f'{name}: {len(data)} bytes')


if __name__ == '__main__':
    main()
