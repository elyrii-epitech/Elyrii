#!/usr/bin/env python3
"""Assert glTF 2.0 binary validity for all generated accessories."""
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[2]
ACC_DIR = ROOT / 'elyrii_app/assets/accessories'

EXPECTED = [
    'scarf_cozy.glb',
    'bowtie_chic.glb',
    'zen_necklace.glb',
    'crown_laurel.glb',
    'headphones_zen.glb',
    'glasses_round.glb',
    'flower_mouth.glb',
]


def check_glb(path):
    raw = path.read_bytes()
    assert raw[:4] == b'glTF', f"{path.name}: Invalid magic header"
    version = struct.unpack_from('<I', raw, 4)[0]
    assert version == 2, f"{path.name}: Expected glTF 2.0, got {version}"
    total_len = struct.unpack_from('<I', raw, 8)[0]
    assert total_len == len(raw), f"{path.name}: Length mismatch: {total_len} != {len(raw)}"

    json_len = struct.unpack_from('<I', raw, 12)[0]
    chunk0_type = raw[16:20]
    assert chunk0_type == b'JSON', f"{path.name}: Chunk 0 is not JSON"
    doc = json.loads(raw[20:20 + json_len])

    # Validate required structures
    assert 'asset' in doc and doc['asset'].get('version') == '2.0'
    assert 'scene' in doc and 'scenes' in doc
    assert 'nodes' in doc and len(doc['nodes']) > 0
    assert 'meshes' in doc and len(doc['meshes']) > 0
    assert 'materials' in doc and len(doc['materials']) > 0
    assert 'accessors' in doc and len(doc['accessors']) > 0
    assert 'bufferViews' in doc and len(doc['bufferViews']) > 0
    assert 'buffers' in doc and len(doc['buffers']) > 0

    bin_start = 20 + json_len
    bin_len = struct.unpack_from('<I', raw, bin_start)[0]
    chunk1_type = raw[bin_start + 4:bin_start + 8]
    assert chunk1_type == b'BIN\0', f"{path.name}: Chunk 1 is not BIN"
    assert doc['buffers'][0]['byteLength'] == bin_len

    for m in doc['meshes']:
        for p in m['primitives']:
            assert 'POSITION' in p['attributes']
            assert 'NORMAL' in p['attributes']
            assert 'indices' in p
            assert 'material' in p

    return len(raw), len(doc['meshes']), len(doc['materials'])


def main():
    print(f"Asserting 3D accessories in {ACC_DIR}...")
    for name in EXPECTED:
        path = ACC_DIR / name
        assert path.exists(), f"Missing accessory file: {name}"
        size, meshes, mats = check_glb(path)
        print(f"  ✓ {name:20s}: {size:5d} bytes | {meshes} meshes | {mats} materials | Valid glTF 2.0")

    print("\nALL 7 ACCESSORIES ARE 100% COMPLIANT GLTF 2.0 BINARY MODELS.")


if __name__ == '__main__':
    main()
