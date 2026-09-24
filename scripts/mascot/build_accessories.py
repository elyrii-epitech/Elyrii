#!/usr/bin/env python3
"""Master 3D Accessories Studio for Elyrii Mascot - Flawless Anatomic Fitting.

Exact anatomical positions:
- Eyes: X = +/- 0.22, Y = 0.46, Z = 0.42 (CTRL_head)
- Ears: X = +/- 0.45, Y = 0.74, Z = 0.0 (CTRL_head)
- Top of Skull: Y = 0.94 (CTRL_head)
- Neck: Y = 0.46, Z = 0.10 (CTRL_chest)

Accessories:
1. scarf_cozy: Écharpe Moelleuse Cocon (GARDÉE : Parfaite)
2. bowtie_chic: Nœud Papillon Célébration (GARDÉ : Parfait)
3. zen_necklace: Collier de Perles Fines (U-drapeau blanc nacre, serré au cou)
4. custom1: Grand Chapeau de Diplômé Royal (mortier 1.05m bleu nuit/or + pompon doré)
5. crown_laurel: Couronne de Laurier Vert Impérial (feuilles vertes éclatantes)
6. headphones_zen: Vrai Casque Gamer Pro (arceau arch ONLY over head Y=0.96, oreillettes sur oreilles Y=0.74, micro perche)
7. glasses_round: Lunettes Noires Ray-Ban (monture acétate noire mate VERTICALE sur les yeux X=+/-0.22, Y=0.46, branches horizontales)
8. flower_mouth: Étoile Scintillante Céleste (cyan néon / saphir étincelant à fort contraste)
"""
import json
import math
from pathlib import Path
import struct

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


def make_torus_arch(ring_r, pipe_r, ring_segs=24, pipe_segs=12, offset=(0, 0, 0), scale=(1, 1, 1), start_angle=0.0, end_angle=math.pi):
    """Arch going ONLY over the skull, NEVER looping underneath!"""
    verts, norms, indices = [], [], []
    for i in range(ring_segs + 1):
        frac = i / float(ring_segs)
        theta = start_angle + frac * (end_angle - start_angle)
        cos_t, sin_t = math.cos(theta), math.sin(theta)
        for j in range(pipe_segs):
            phi = 2.0 * math.pi * j / pipe_segs
            cos_p, sin_p = math.cos(phi), math.sin(phi)
            cx = (ring_r + pipe_r * cos_p) * cos_t
            cy = (ring_r + pipe_r * cos_p) * sin_t
            cz = pipe_r * sin_p
            nx = cos_p * cos_t
            ny = cos_p * sin_t
            nz = sin_p
            verts.append((offset[0] + cx * scale[0], offset[1] + cy * scale[1], offset[2] + cz * scale[2]))
            norms.append((nx, ny, nz))

    for i in range(ring_segs):
        for j in range(pipe_segs):
            j_next = (j + 1) % pipe_segs
            i0 = i * pipe_segs + j
            i1 = (i + 1) * pipe_segs + j
            i2 = (i + 1) * pipe_segs + j_next
            i3 = i * pipe_segs + j_next
            indices.extend([i0, i1, i2, i0, i2, i3])
    return verts, norms, indices


def make_vertical_rim(ring_r, pipe_r, center_x, center_y, center_z, segs=28, pipe_segs=10):
    """Vertical ring in X-Y plane facing the viewer."""
    verts, norms, indices = [], [], []
    for i in range(segs):
        theta = 2.0 * math.pi * i / segs
        cos_t, sin_t = math.cos(theta), math.sin(theta)
        for j in range(pipe_segs):
            phi = 2.0 * math.pi * j / pipe_segs
            cos_p, sin_p = math.cos(phi), math.sin(phi)
            r = ring_r + pipe_r * cos_p
            x = center_x + r * cos_t
            y = center_y + r * sin_t
            z = center_z + pipe_r * sin_p
            nx = cos_p * cos_t
            ny = cos_p * sin_t
            nz = sin_p
            verts.append((x, y, z))
            norms.append((nx, ny, nz))
    for i in range(segs):
        i_next = (i + 1) % segs
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
            norms.append((nx, ny, nz))

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


# ==============================================================================
# 1 & 2: ACCESSORIES GARDÉS (Écharpe & Nœud Papillon)
# ==============================================================================

def build_scarf_cozy():
    builder = GLBBuilder()
    wool_mat = builder.add_material('WoolTerracotta', [0.88, 0.46, 0.28, 1.0], roughness=0.85, metallic=0.0)
    pin_mat = builder.add_material('GoldPin', [0.98, 0.82, 0.32, 1.0], roughness=0.20, metallic=0.90)

    geoms_wool = []
    geoms_wool.append(make_torus(ring_r=0.46, pipe_r=0.10, ring_segs=32, pipe_segs=16, offset=(0, 0.05, 0.02), scale=(1.0, 0.85, 0.95), rot_x=0.05))
    geoms_wool.append(make_torus(ring_r=0.42, pipe_r=0.08, ring_segs=28, pipe_segs=14, offset=(0, -0.04, 0.06), scale=(0.95, 0.80, 0.90), rot_x=0.10))
    geoms_wool.append(make_box(0.15, 0.38, 0.07, offset=(0.14, -0.24, 0.44)))

    geoms_pin = []
    geoms_pin.append(make_sphere(0.038, rings=10, segs=12, offset=(0.14, -0.08, 0.48), scale=(1.0, 0.6, 0.4)))

    v, n, i = merge_geometries(geoms_wool)
    builder.add_mesh_primitive(v, n, i, wool_mat)
    v, n, i = merge_geometries(geoms_pin)
    builder.add_mesh_primitive(v, n, i, pin_mat)
    return builder.build_glb_bytes()


def build_bowtie_chic():
    builder = GLBBuilder()
    fabric_mat = builder.add_material('VelvetCrimson', [0.72, 0.14, 0.32, 1.0], roughness=0.65, metallic=0.05)
    gold_mat = builder.add_material('PolishedGold', [0.98, 0.82, 0.32, 1.0], roughness=0.18, metallic=0.90)

    geoms_fabric = []
    geoms_fabric.append(make_sphere(0.12, rings=14, segs=16, offset=(0.15, 0.0, 0.0), scale=(1.3, 0.85, 0.55)))
    geoms_fabric.append(make_sphere(0.12, rings=14, segs=16, offset=(-0.15, 0.0, 0.0), scale=(1.3, 0.85, 0.55)))
    geoms_fabric.append(make_box(0.08, 0.16, 0.03, offset=(0.06, -0.11, 0.02)))
    geoms_fabric.append(make_box(0.08, 0.16, 0.03, offset=(-0.06, -0.11, 0.02)))

    geoms_gold = []
    geoms_gold.append(make_torus(ring_r=0.055, pipe_r=0.028, ring_segs=20, pipe_segs=10, offset=(0.0, 0.0, 0.03), scale=(0.85, 1.2, 1.0)))

    v, n, i = merge_geometries(geoms_fabric)
    builder.add_mesh_primitive(v, n, i, fabric_mat)
    v, n, i = merge_geometries(geoms_gold)
    builder.add_mesh_primitive(v, n, i, gold_mat)
    return builder.build_glb_bytes()


# ==============================================================================
# 3. Collier de Perles Fines (CALÉ PARFAITEMENT AU COU : rayon 0.28, U-curve fluide)
# ==============================================================================
def build_zen_necklace():
    builder = GLBBuilder()
    pearl_mat = builder.add_material('LustrousCreamPearl', [0.98, 0.96, 0.92, 1.0], roughness=0.20, metallic=0.10)
    gold_clasp = builder.add_material('ClaspGold', [0.98, 0.84, 0.32, 1.0], roughness=0.15, metallic=0.92)

    geoms_pearls = []
    # 26 round pearls closely draping around the bear's neck:
    # X spans +/- 0.26, Y starts at 0.08 and dips to -0.10 in front, Z goes from -0.05 to 0.26
    num_pearls = 26
    rx = 0.26
    for i in range(num_pearls):
        theta = 2.0 * math.pi * i / num_pearls
        cos_t = math.cos(theta)
        sin_t = math.sin(theta)
        px = rx * sin_t
        # U-curve: dips in front (when cos_t < 0)
        py = 0.06 - 0.14 * (0.5 * (1.0 - cos_t))
        pz = 0.16 * cos_t + 0.10
        p_r = 0.030 if cos_t < 0 else 0.024
        geoms_pearls.append(make_sphere(p_r, rings=8, segs=10, offset=(px, py, pz)))

    geoms_gold = []
    # Drop pearl pendant in center
    geoms_gold.append(make_sphere(0.036, rings=10, segs=10, offset=(0.0, -0.12, 0.28)))
    geoms_gold.append(make_cylinder(0.010, 0.010, 0.025, segs=8, offset=(0.0, -0.08, 0.27)))

    v, n, i = merge_geometries(geoms_pearls)
    builder.add_mesh_primitive(v, n, i, pearl_mat)
    v, n, i = merge_geometries(geoms_gold)
    builder.add_mesh_primitive(v, n, i, gold_clasp)
    return builder.build_glb_bytes()


# ==============================================================================
# 4. Grand Chapeau de Diplômé Royal (1.05m BLEU NUIT & OR AVEC VRAI POMPON TOUFFU)
# ==============================================================================
def build_custom1():
    builder = GLBBuilder()
    silk_mat = builder.add_material('RoyalMidnightFelt', [0.10, 0.14, 0.26, 1.0], roughness=0.40, metallic=0.08)
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


# ==============================================================================
# 5. Couronne de Laurier Vert Impérial (VRAIES FEUILLES VERTES NATURELLES)
# ==============================================================================
def build_crown_laurel():
    builder = GLBBuilder()
    leaf_mat = builder.add_material('TrueGreenLaurel', [0.16, 0.60, 0.22, 1.0], roughness=0.40, metallic=0.0)
    stem_mat = builder.add_material('BranchWood', [0.36, 0.25, 0.18, 1.0], roughness=0.65, metallic=0.0)
    berry_mat = builder.add_material('GoldenOlives', [0.98, 0.84, 0.32, 1.0], roughness=0.15, metallic=0.92)

    geoms_stem = []
    geoms_stem.append(make_torus(ring_r=0.55, pipe_r=0.018, ring_segs=32, pipe_segs=8, offset=(0.0, 0.0, 0.0), scale=(0.96, 0.80, 0.98), rot_x=-0.22))

    geoms_leaf = []
    sin_tilt, cos_tilt = math.sin(-0.22), math.cos(-0.22)
    for p in range(20):
        angle = 2.0 * math.pi * p / 20.0
        cx = 0.55 * 0.96 * math.cos(angle)
        cz = 0.55 * 0.98 * math.sin(angle)
        cy = -cz * sin_tilt
        cz_rot = cz * cos_tilt
        geoms_leaf.append(make_sphere(0.065, rings=8, segs=10, offset=(cx + 0.025, cy + 0.045, cz_rot + 0.02), scale=(0.40, 1.35, 0.25)))
        geoms_leaf.append(make_sphere(0.065, rings=8, segs=10, offset=(cx - 0.025, cy + 0.035, cz_rot - 0.02), scale=(0.40, 1.35, 0.25)))

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


# ==============================================================================
# 6. Vrai Casque Gamer Pro (ARCEAU OUVRE AU DESSUS DU CRÂNE Y=0.96, OREILLES Y=0.74, MICRO PERCHE)
# ==============================================================================
def build_headphones_zen():
    builder = GLBBuilder()
    chassis_mat = builder.add_material('MatteGamerBlack', [0.12, 0.12, 0.14, 1.0], roughness=0.35, metallic=0.15)
    rgb_cyan = builder.add_material('NeonRGBCyan', [0.0, 0.95, 0.90, 1.0], roughness=0.10, metallic=0.10, emissive=[0.10, 0.90, 0.85])
    cushion_mat = builder.add_material('PlushEarCushion', [0.18, 0.18, 0.22, 1.0], roughness=0.80, metallic=0.0)
    steel_mat = builder.add_material('SteelMic', [0.85, 0.88, 0.92, 1.0], roughness=0.20, metallic=0.90)

    geoms_chassis = []
    # Arceau semi-circulaire ouvert (make_torus_arch) qui passe UNIQUEMENT par dessus la tête de 0 à pi!
    # Base aux oreilles (Y=0.74, X=+/-0.46), sommet à Y=0.74 + 0.22 = 0.96!
    # AUCUN anneau qui traverse le front ou les yeux!
    geoms_chassis.append(make_torus_arch(ring_r=0.46, pipe_r=0.040, ring_segs=24, pipe_segs=12, offset=(0.0, 0.74, 0.0), scale=(1.02, 0.52, 0.70), start_angle=0.0, end_angle=math.pi))

    # Large gaming earcups seated RIGHT ON THE BEAR'S EARS at X = +/- 0.46, Y = 0.74!
    geoms_chassis.append(make_cylinder(0.16, 0.18, 0.10, segs=24, offset=(0.46, 0.74, 0.0), scale=(0.55, 1.05, 0.95)))
    geoms_chassis.append(make_cylinder(0.16, 0.18, 0.10, segs=24, offset=(-0.46, 0.74, 0.0), scale=(0.55, 1.05, 0.95)))

    geoms_cushion = []
    # Inward cushions
    geoms_cushion.append(make_torus(ring_r=0.13, pipe_r=0.042, ring_segs=20, pipe_segs=8, offset=(0.42, 0.74, 0.0), scale=(0.5, 1.05, 0.95), rot_x=0.0))
    geoms_cushion.append(make_torus(ring_r=0.13, pipe_r=0.042, ring_segs=20, pipe_segs=8, offset=(-0.42, 0.74, 0.0), scale=(0.5, 1.05, 0.95), rot_x=0.0))

    geoms_rgb = []
    # Glowing RGB ring on the outer shell
    geoms_rgb.append(make_torus(ring_r=0.12, pipe_r=0.015, ring_segs=20, pipe_segs=8, offset=(0.49, 0.74, 0.0), scale=(0.5, 1.0, 0.9), rot_x=0.0))
    geoms_rgb.append(make_torus(ring_r=0.12, pipe_r=0.015, ring_segs=20, pipe_segs=8, offset=(-0.49, 0.74, 0.0), scale=(0.5, 1.0, 0.9), rot_x=0.0))

    geoms_mic = []
    # Gamer boom mic from left earcup curving around cheek toward mouth!
    geoms_mic.append(make_cylinder(0.012, 0.012, 0.38, segs=8, offset=(-0.40, 0.54, 0.20), scale=(1.0, 1.0, 1.0), rot_x=0.65, rot_z=-0.45))
    geoms_mic.append(make_sphere(0.030, rings=8, segs=8, offset=(-0.24, 0.36, 0.40)))

    v, n, i = merge_geometries(geoms_chassis)
    builder.add_mesh_primitive(v, n, i, chassis_mat)
    v, n, i = merge_geometries(geoms_rgb)
    builder.add_mesh_primitive(v, n, i, rgb_cyan)
    v, n, i = merge_geometries(geoms_cushion)
    builder.add_mesh_primitive(v, n, i, cushion_mat)
    v, n, i = merge_geometries(geoms_mic)
    builder.add_mesh_primitive(v, n, i, steel_mat)
    return builder.build_glb_bytes()


# ==============================================================================
# 7. Lunettes Noires Style Ray-Ban (ACÉTATE NOIRE MATE, VRAIS RIMS VERTICAUX DEVANT LES YEUX X=+/-0.22, Y=0.46)
# ==============================================================================
def build_glasses_round():
    builder = GLBBuilder()
    # MATTE BLACK ACETATE (roughness 0.65, metallic 0.0 - NO CHROME REFLECTION!)
    acetate_mat = builder.add_material('MatteBlackRayBan', [0.08, 0.08, 0.10, 1.0], roughness=0.65, metallic=0.0)
    silver_rivet = builder.add_material('SilverRivet', [0.90, 0.90, 0.92, 1.0], roughness=0.20, metallic=0.90)
    tinted_lens = builder.add_material('SmokeTintedLens', [0.10, 0.12, 0.14, 0.65], roughness=0.15, metallic=0.0)

    geoms_frame = []
    rim_r = 0.14 # Compact, perfectly encasing the eyes
    rim_pipe = 0.022
    spacing = 0.22 # Exact eye distance
    eye_y = 0.46
    eye_z = 0.42

    # Two VERTICAL rings in the X-Y plane using make_vertical_rim (NO HORIZONTAL CUTTING!)
    geoms_frame.append(make_vertical_rim(rim_r, rim_pipe, spacing, eye_y, eye_z))
    geoms_frame.append(make_vertical_rim(rim_r, rim_pipe, -spacing, eye_y, eye_z))

    # Bold bridge arched across the snout
    geoms_frame.append(make_box(0.12, 0.035, 0.025, offset=(0.0, eye_y + 0.04, eye_z)))

    # Real horizontal temples (branches) extending straight back from frame corners to the ears!
    temple_x = spacing + rim_r * 0.95
    geoms_frame.append(make_box(0.025, 0.028, 0.46, offset=(temple_x, eye_y + 0.02, eye_z - 0.23)))
    geoms_frame.append(make_box(0.025, 0.028, 0.46, offset=(-temple_x, eye_y + 0.02, eye_z - 0.23)))

    geoms_rivet = []
    # Horizontal silver dot rivets on the front corners (Ray-Ban signature)
    geoms_rivet.append(make_sphere(0.012, rings=6, segs=6, offset=(temple_x - 0.02, eye_y + 0.03, eye_z + 0.02)))
    geoms_rivet.append(make_sphere(0.012, rings=6, segs=6, offset=(-(temple_x - 0.02), eye_y + 0.03, eye_z + 0.02)))

    geoms_lens = []
    # Tinted lenses sitting vertically in the rims
    geoms_lens.append(make_cylinder(rim_r * 0.94, rim_r * 0.94, 0.008, segs=24, offset=(spacing, eye_y, eye_z), rot_x=math.pi/2))
    geoms_lens.append(make_cylinder(rim_r * 0.94, rim_r * 0.94, 0.008, segs=24, offset=(-spacing, eye_y, eye_z), rot_x=math.pi/2))

    v, n, i = merge_geometries(geoms_frame)
    builder.add_mesh_primitive(v, n, i, acetate_mat)
    v, n, i = merge_geometries(geoms_rivet)
    builder.add_mesh_primitive(v, n, i, silver_rivet)
    v, n, i = merge_geometries(geoms_lens)
    builder.add_mesh_primitive(v, n, i, tinted_lens)
    return builder.build_glb_bytes()


# ==============================================================================
# 8. Étoile Scintillante Céleste (VIBRANT NEON CYAN / SAPHIR HYPER BRILLANTE SUR LA TEMPE)
# ==============================================================================
def build_flower_mouth():
    builder = GLBBuilder()
    # Glowing vibrant radiant cyan/sapphire star (emissive pops against warm fur!)
    star_mat = builder.add_material('RadiantCyanGlow', [0.0, 0.92, 1.0, 1.0], roughness=0.05, metallic=0.20, emissive=[0.25, 0.95, 1.0])
    core_mat = builder.add_material('DiamondSparkleCore', [0.98, 1.0, 1.0, 1.0], roughness=0.01, metallic=0.50, emissive=[0.60, 0.90, 1.0])

    geoms_star = []
    # Prominent 4-pointed radiant sparkle star placed right above cheek blush (X=0.34, Y=0.48, Z=0.44)
    geoms_star.append(make_sphere(0.12, rings=10, segs=12, offset=(0.34, 0.48, 0.44), scale=(2.2, 0.35, 0.45)))
    geoms_star.append(make_sphere(0.12, rings=10, segs=12, offset=(0.34, 0.48, 0.44), scale=(0.35, 2.2, 0.45)))
    # Diagonal sparkles
    geoms_star.append(make_sphere(0.08, rings=8, segs=8, offset=(0.34, 0.48, 0.44), scale=(1.2, 1.2, 0.4)))

    geoms_core = []
    # Glowing diamond center
    geoms_core.append(make_sphere(0.055, rings=8, segs=10, offset=(0.34, 0.48, 0.46)))

    v, n, i = merge_geometries(geoms_star)
    builder.add_mesh_primitive(v, n, i, star_mat)
    v, n, i = merge_geometries(geoms_core)
    builder.add_mesh_primitive(v, n, i, core_mat)
    return builder.build_glb_bytes()


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    models = {
        'scarf_cozy.glb': build_scarf_cozy(),
        'bowtie_chic.glb': build_bowtie_chic(),
        'zen_necklace.glb': build_zen_necklace(),
        'crown_laurel.glb': build_crown_laurel(),
        'headphones_zen.glb': build_headphones_zen(),
        'glasses_round.glb': build_glasses_round(),
        'flower_mouth.glb': build_flower_mouth(),
        '../custom1.glb': build_custom1(),
    }
    for filename, glb_bytes in models.items():
        out_file = OUTPUT_DIR / filename
        out_file.write_bytes(glb_bytes)
        print(f"Generated {filename}: {len(glb_bytes) / 1024:.1f} KB")

if __name__ == '__main__':
    main()
