"""Check encoded GLB curves, catalog and unchanged geometry; no dependencies.

  python3 scripts/mascot/check_velours_motion.py [--compare-ref HEAD]
"""
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path
import re
import struct
import subprocess
import tempfile

from build_velours_motion import ASSET, CLIPS, ROOT, read_glb, remove_animations


def values(g, data, index):
    a = g['accessors'][index]
    width = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}[a['type']]
    v = g['bufferViews'][a['bufferView']]
    offset = v.get('byteOffset', 0) + a.get('byteOffset', 0)
    flat = struct.unpack_from('<'+'f'*(a['count']*width), data, offset)
    return [flat[i:i+width] for i in range(0, len(flat), width)]


def check(compare_ref=None):
    g, binary = read_glb(ASSET)
    assert {a['name'] for a in g['animations']} == set(CLIPS)
    dart = (ROOT/'elyrii_app/lib/core/config/mascot_animations.dart').read_text()
    catalog = json.loads((Path(__file__).parent/'clips.json').read_text())
    rest = None
    frames = 0
    for a in g['animations']:
        name = a['name']
        signatures = []
        duration = CLIPS[name][1]
        assert catalog[name] == a['extras']
        assert re.search(r"clipName: '"+name+r"'.*?Duration\(milliseconds: "+str(round(duration*1000))+r"\)", dart, re.S)
        for ch in a['channels']:
            sampler = a['samplers'][ch['sampler']]
            times = [row[0] for row in values(g, binary, sampler['input'])]
            rows = values(g, binary, sampler['output'])
            path = ch['target']['path']
            if path == 'weights':
                flat = [r[0] for r in rows]
                rows = [flat[i:i+2] for i in range(0, len(flat), 2)]
            assert len(times) == len(rows)
            assert times[0] == 0 and abs(times[-1]-duration) < 1e-6
            assert all(b > a for a, b in zip(times, times[1:]))
            assert all(math.isfinite(v) for row in rows for v in row)
            assert max(abs(a-b) for a, b in zip(rows[0], rows[-1])) < 1e-6, name
            if path == 'rotation':
                assert all(abs(sum(v*v for v in row)-1) < 1e-6 for row in rows)
            elif path == 'scale':
                assert all(.9 < v < 1.1 for row in rows for v in row)
            elif path == 'weights':
                assert all(all(0 <= v <= 1 for v in row) and sum(row) <= 1.000001 for row in rows)
            node = ch['target']['node']
            assert g['nodes'][node]['name'].startswith(('CTRL_', 'LID_'))
            signatures.append((node, path, tuple(rows[0])))
        if rest is None:
            rest = signatures
        assert signatures == rest, name+' must blend from the common rest pose'
        frames += len(times)

    # Geometry, skins, images and material payloads survive rebuilding.
    geometry = remove_animations(copy.deepcopy(g), binary)
    if compare_ref:
        raw = subprocess.check_output(['git', 'show', f'{compare_ref}:elyrii_app/assets/elyrii_velours_animations.glb'], cwd=ROOT)
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp)/'before.glb'
            path.write_bytes(raw)
            before, before_data = read_glb(path)
        assert before['nodes'] == g['nodes']
        assert before['materials'] == g['materials']
        assert remove_animations(before, before_data) == geometry
        compacted = _compacted(g, binary)
        for key in ('meshes', 'skins', 'images', 'textures'):
            assert before.get(key) == compacted.get(key), key
    print(f'OK: {len(CLIPS)} clips, {frames} poses, normalized quaternions, common endpoints, bounded eyelids, catalog matches GLB.')
    print('Geometry SHA256:', hashlib.sha256(geometry).hexdigest())


def _compacted(g, binary):
    result = copy.deepcopy(g)
    remove_animations(result, binary)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--compare-ref')
    check(parser.parse_args().compare_ref)
