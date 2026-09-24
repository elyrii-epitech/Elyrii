#!/usr/bin/env python3
"""Build Velours multi-variant 3D model using KHR_materials_variants glTF extension.

Generates 5 authentic color variants ('Astral', 'Zen', 'Automne', 'Sakura', 'Panda')
alongside the original 'Elyrii' palette, using indexed 2048x2048 PNG textures and
properly adjusted eyelid baseColorFactors.

Standard Python library + PIL only.
Usage:
    python3 scripts/mascot/build_velours_variants.py
"""
import io
import json
import math
from pathlib import Path
import struct
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSET = ROOT / 'elyrii_app/assets/elyrii_velours_animations.glb'
VARIANTS = [
    {
        'id': 'nature',
        'name': 'Elyrii',
        'fur': '#f2d0a8',
        'belly': '#fefff3',
        'blush_ear': '#fe9186',
        'iris_shadow': '#a48c95',
        'pupil_linework': '#420e30',
    },
    {
        'id': 'cosmic',
        'name': 'Astral',
        'fur': '#2d3561',
        'belly': '#c5cae9',
        'blush_ear': '#f2ce94',
        'iris_shadow': '#464a78',
        'pupil_linework': '#151833',
    },
    {
        'id': 'zen',
        'name': 'Zen',
        'fur': '#8aa882',
        'belly': '#f1f8e9',
        'blush_ear': '#c8e6c9',
        'iris_shadow': '#3a5440',
        'pupil_linework': '#152418',
    },
    {
        'id': 'halloween',
        'name': 'Automne',
        'fur': '#e67e22',
        'belly': '#fff8e1',
        'blush_ear': '#c48668',
        'iris_shadow': '#523425',
        'pupil_linework': '#23150e',
    },
    {
        'id': 'sakura',
        'name': 'Sakura',
        'fur': '#f48fb1',
        'belly': '#fff5f8',
        'blush_ear': '#f8bbd0',
        'iris_shadow': '#622b7a',
        'pupil_linework': '#2e1042',
    },
    {
        'id': 'panda',
        'name': 'Panda',
        'fur': '#f5f5f7',
        'belly': '#ffffff',
        'blush_ear': '#263238',
        'iris_shadow': '#3a3a3a',
        'pupil_linework': '#121212',
    },
]
def read_glb(path):
    raw = path.read_bytes()
    assert raw[:4] == b'glTF'
    length = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20 + length])
    start = 20 + length
    bin_len = struct.unpack_from('<I', raw, start)[0]
    binary = bytearray(raw[start + 8:start + 8 + bin_len])
    return doc, binary


def hex_to_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def srgb_to_linear(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def build_palette(orig_pal, variant):
    """Build an authentic 128-color RGB palette preserving shading, cute soulful eyes, and occlusion."""
    pal = []

    belly_rgb = hex_to_rgb(variant['belly'])
    fur_rgb = hex_to_rgb(variant['fur'])
    blush_rgb = hex_to_rgb(variant['blush_ear'])
    iris_shadow_rgb = hex_to_rgb(variant['iris_shadow'])
    pupil_rgb = hex_to_rgb(variant['pupil_linework'])

    orig_belly0 = (orig_pal[0], orig_pal[1], orig_pal[2])
    orig_fur26 = (orig_pal[26*3], orig_pal[26*3+1], orig_pal[26*3+2])
    orig_ear68 = (orig_pal[68*3], orig_pal[68*3+1], orig_pal[68*3+2])

    for i in range(128):
        orig_c = (orig_pal[i*3], orig_pal[i*3+1], orig_pal[i*3+2])

        if 0 <= i <= 11:
            # 0..11: Belly, muzzle, eye whites, highlights
            ratio = [orig_c[c] / max(1, orig_belly0[c]) for c in range(3)]
            color = [round(belly_rgb[c] * ratio[c]) for c in range(3)]
        elif 12 <= i <= 59:
            # 12..59: Main fur (body, head, legs, tail)
            ratio = [orig_c[c] / max(1, orig_fur26[c]) for c in range(3)]
            color = [round(fur_rgb[c] * ratio[c]) for c in range(3)]
        elif 60 <= i <= 76:
            # 60..76: Ear interior, blush, muzzle tender
            w = (orig_fur26[1] - orig_c[1]) / max(1, orig_fur26[1] - orig_ear68[1])
            w = max(0.0, min(1.0, w))
            color = [
                round((1.0 - w) * fur_rgb[c] + w * blush_rgb[c])
                for c in range(3)
            ]
        else:
            # 77..127: Eyes, pupil, linework, deep shadows
            # Smooth gradient from soft iris shadow to deep dark pupil/linework
            t = (i - 77) / (127 - 77)
            color = [
                round((1.0 - t) * iris_shadow_rgb[c] + t * pupil_rgb[c])
                for c in range(3)
            ]

        color = [max(0, min(255, c)) for c in color]
        pal.extend(color)

    return pal


def generate_variant_image_bytes(base_img, palette, target_size=(512, 512)):
    """Create a new indexed PNG with the specified palette, optimized for WebGL memory."""
    variant_img = base_img.copy()
    variant_img.putpalette(palette)
    if target_size and target_size != variant_img.size:
        variant_img = variant_img.resize(target_size, resample=Image.Resampling.NEAREST)
    buf = io.BytesIO()
    variant_img.save(buf, format='PNG', optimize=True)
    return buf.getvalue()

def build_variants():
    doc, binary = read_glb(ASSET)

    # 1. Verify base image 0
    img0_bv = doc['bufferViews'][doc['images'][0]['bufferView']]
    img0_offset = img0_bv.get('byteOffset', 0)
    img0_data = binary[img0_offset:img0_offset + img0_bv['byteLength']]
    base_img = Image.open(io.BytesIO(img0_data))
    assert base_img.mode == 'P'
    orig_palette = base_img.getpalette()

    # 2. Extensions registration
    doc.setdefault('extensionsUsed', [])
    if 'KHR_materials_variants' not in doc['extensionsUsed']:
        doc['extensionsUsed'].append('KHR_materials_variants')

    doc.setdefault('extensions', {})
    doc['extensions']['KHR_materials_variants'] = {
        'variants': [{'name': v['name']} for v in VARIANTS]
    }

    # 3. Create textures and materials for the 5 additional variants
    # Variant 0 ("Elyrii") uses materials 0..12
    variant_materials = [[i for i in range(13)]] # list of 13 material indices per variant

    for v_idx in range(1, len(VARIANTS)):
        variant = VARIANTS[v_idx]
        print(f"Building textures & materials for variant {variant['name']}...")
        
        # Build palette & PNG
        pal = build_palette(orig_palette, variant)
        png_bytes = generate_variant_image_bytes(base_img, pal)

        # Pad binary buffer to 4-byte boundary
        binary.extend(b'\0' * (-len(binary) % 4))
        bv_offset = len(binary)
        binary.extend(png_bytes)

        bv_index = len(doc['bufferViews'])
        doc['bufferViews'].append({
            'buffer': 0,
            'byteOffset': bv_offset,
            'byteLength': len(png_bytes),
        })

        image_index = len(doc['images'])
        doc['images'].append({
            'name': f"elyrii_d_palette_{variant['id']}",
            'mimeType': 'image/png',
            'bufferView': bv_index,
        })

        # Create textures for this variant (reuse sampler 0)
        # We create a texture referencing the new image
        tex_index = len(doc['textures'])
        doc['textures'].append({
            'sampler': 0,
            'source': image_index,
        })

        # Eyelid linear baseColorFactor from fur color
        fur_rgb = hex_to_rgb(variant['fur'])
        eyelid_linear = [srgb_to_linear(c) for c in fur_rgb] + [1.0]
        emissive_scaled = [srgb_to_linear(c) * 0.25 for c in fur_rgb]

        # Create 13 materials for this variant
        mat_indices = []
        for orig_m_idx in range(13):
            orig_m = doc['materials'][orig_m_idx]
            new_m = json.loads(json.dumps(orig_m)) # deepcopy
            new_m['name'] = f"{orig_m.get('name', 'mat')}_{variant['id']}"

            if orig_m_idx < 12:
                # Point baseColorTexture to the new variant texture
                pbr = new_m.setdefault('pbrMetallicRoughness', {})
                pbr.setdefault('baseColorTexture', {})['index'] = tex_index
                # Calibrate emissive properties for the variant
                if 'emissiveTexture' in new_m:
                    new_m['emissiveTexture']['index'] = tex_index
                if 'emissiveFactor' in new_m and orig_m.get('emissiveFactor') != [0, 0, 0]:
                    new_m['emissiveFactor'] = emissive_scaled
            else:
                # Material 12: eyelids color matching fur
                pbr = new_m.setdefault('pbrMetallicRoughness', {})
                pbr['baseColorFactor'] = eyelid_linear
                if 'emissiveFactor' in new_m:
                    new_m['emissiveFactor'] = emissive_scaled

            new_m_idx = len(doc['materials'])
            doc['materials'].append(new_m)
            mat_indices.append(new_m_idx)
        variant_materials.append(mat_indices)

    # 4. Add KHR_materials_variants mappings to all primitives
    for mesh in doc['meshes']:
        for prim in mesh['primitives']:
            default_mat = prim['material']
            mappings = []
            for v_idx in range(len(VARIANTS)):
                mat_for_variant = variant_materials[v_idx][default_mat]
                mappings.append({
                    'material': mat_for_variant,
                    'variants': [v_idx],
                })
            prim.setdefault('extensions', {})['KHR_materials_variants'] = {
                'mappings': mappings
            }

    # 5. Update buffers & write out GLB
    doc['buffers'][0]['byteLength'] = len(binary)
    doc.setdefault('asset', {})['generator'] = 'Elyrii Velours multi-variant motion library / 2026-09'

    encoded = json.dumps(doc, separators=(',', ':')).encode()
    encoded += b' ' * (-len(encoded) % 4)
    binary.extend(b'\0' * (-len(binary) % 4))

    raw = struct.pack('<4sII', b'glTF', 2, 28 + len(encoded) + len(binary))
    raw += struct.pack('<I4s', len(encoded), b'JSON') + encoded
    raw += struct.pack('<I4s', len(binary), b'BIN\0') + binary

    ASSET.write_bytes(raw)
    print(f"Successfully generated multi-variant GLB: {len(raw)} bytes ({len(raw)/1024/1024:.2f} MB)")
    print(f"Variants registered: {[v['name'] for v in VARIANTS]}")


if __name__ == '__main__':
    build_variants()
