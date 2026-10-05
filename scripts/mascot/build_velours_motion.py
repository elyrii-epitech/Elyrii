"""Rebuild Velours' motion library without touching its meshes or materials.

Python standard library only. Run from any directory:
  python3 scripts/mascot/build_velours_motion.py
The existing rigged app GLB is the input AND output; rebuilding is idempotent.
Angles are degrees; translations use the rig's local coordinates. Quintic
easing, shared rest poses and delayed secondary motion keep transitions soft.
"""
from pathlib import Path
import copy
import hashlib
import json
import math
import struct

ROOT = Path(__file__).resolve().parents[2]
ASSET = ROOT / 'elyrii_app/assets/elyrii_velours_animations.glb'
FPS = 30
CLIPS = {
    'idle': ('Présence', 12.0, 'loop', 'Deux souffles discrets, regard vivant et clignements espacés.'),
    'greet': ('Bonjour !', 3.2, 'once', 'Anticipation, patte relevée, deux salutations du poignet.'),
    'attentive': ('Je t’écoute', 6.4, 'loop', 'Inclinaison, légère avancée et petit acquiescement.'),
    'thinking': ('Je réfléchis', 4.4, 'loop', 'Regard en biais, oreille en retard, retour vers toi.'),
    'celebrate': ('Bravo !', 3.4, 'once', 'Les deux pattes s’ouvrent avec un petit rebond du buste.'),
    'breathe': ('Respirons', 2.0, 'loop', 'Pose pilotée par la progression réelle de la respiration.'),
    'curious': ('Tiens, tiens…', 7.2, 'once', 'Regard à gauche puis à droite, tête penchée et oreille curieuse.'),
    'cozy': ('Bien installé', 8.0, 'once', 'Long clignement paisible et relâchement des épaules.'),
    'acknowledge': ('Je suis là', 2.6, 'once', 'Un signe de tête posé après une réponse ou une humeur partagée.'),
    'reassure': ('À ton rythme', 4.8, 'once', 'La tête s’approche, une patte s’ouvre doucement pour accueillir.'),
    'delight': ('Petit bonheur', 3.6, 'once', 'Deux accents de joie contenus, pattes ouvertes et yeux plissés.'),
    'nuzzle': ('Un peu de douceur', 4.0, 'once', 'Se penche vers toi, ferme les yeux et se redresse doucement.'),
    'proud': ('Ça me va ?', 3.8, 'once', 'Buste redressé, petit regard de chaque côté et salut du poignet.'),
    'stretch': ('Petite pause', 5.6, 'once', 'Étirement asymétrique des pattes, yeux mi-clos, relâchement.'),
    'settle': ('Tout doucement', 5.2, 'once', 'Une longue expiration et un léger signe de tête après la séance.'),
    'invite': ('On y va ?', 3.4, 'once', 'Une patte invite à avancer, suivie d’un acquiescement.'),
}


def read_glb(path):
    raw = path.read_bytes()
    assert raw[:4] == b'glTF'
    length = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20 + length])
    start = 20 + length
    binary_length = struct.unpack_from('<I', raw, start)[0]
    return doc, raw[start + 8:start + 8 + binary_length]


def smooth(x):
    x = max(0, min(1, x))
    return x*x*x*(x*(x*6-15)+10)


def curve(t, points):
    for (a, x), (b, y) in zip(points, points[1:]):
        if t <= b:
            return x + (y-x)*smooth((t-a)/(b-a))
    return points[-1][1]


def blink(t, center, hold=0.045):
    return curve(t, [(0, 0), (center-.13, 0), (center, 1),
                     (center+hold, 1), (center+hold+.22, 0), (100, 0)])


def pose(name, t):
    d = CLIPS[name][1]
    u = t/d
    envelope = math.sin(math.pi*u)**2
    p = {key: [0., 0., 0.] for key in (
        'head', 'arm_right', 'arm_left', 'elbow_right', 'elbow_left',
        'wrist_right', 'wrist_left', 'ear_left', 'ear_right')}
    p.update(head_t=[0., .0025*envelope, 0.], chest_t=[0., 0., 0.],
             chest_s=[1+.006*envelope, 1., 1+.009*envelope], blink=0.)
    def c(points):
        return curve(t, [(0, 0), *points, (d, 0)])
    def arms(lift, flex, front=0):
        for side, sign in [('right', 1), ('left', -1)]:
            p['arm_'+side] = [front, 0, sign*lift]
            p['elbow_'+side][2] = sign*flex
            p['wrist_'+side][2] = -sign*flex*.10

    if name == 'idle':
        breath = math.sin(2*math.pi*u)**2
        p['chest_s'] = [1+.006*breath, 1., 1+.01*breath]
        p['head_t'][1] = .0025*breath
        p['head'][1] = c([(2, .9), (4.5, .9), (7.3, -1.1), (10, -.4)])
        p['head'][2] = .55*math.sin(2*math.pi*u)*envelope
        p['blink'] = max(blink(t, 2.8), blink(t, 7.6), blink(t, 8.05)*.7)
    elif name == 'greet':
        p['arm_right'] = [c([(.85, -8), (2.15, -8), (3.1, 0)]), 0,
                          c([(.18, -1.5), (.78, 31), (2.15, 31), (3.05, 0)])]
        p['elbow_right'][2] = c([(.22, 0), (.94, 88), (2.1, 88), (3.1, 0)])
        p['wrist_right'][2] = c([(.5, 0), (.98, -7), (1.27, 7), (1.6, -8), (1.94, 5), (2.3, -3), (3.08, 0)])
        p['wrist_right'][1] = c([(.6, 0), (1.03, 9), (1.44, -8), (1.84, 8), (2.3, 0)])
        p['head'][2] = c([(.75, -4), (1.8, -3), (3.05, 0)])
        p['head'][0] = c([(.25, 2), (1.05, -2), (2.4, 0)])
        p['elbow_left'][2] = -6*envelope
        p['blink'] = blink(t, 2.55)
    elif name == 'attentive':
        p['head'][2] = c([(1.1, 4.3), (3.8, 4.3), (5.9, 0)])
        p['head'][0] = c([(1.3, 1), (2.35, 4.5), (3.1, 1), (4.5, 1.8), (6, 0)])
        p['head_t'][2] = .012*envelope
        arms(1*envelope, 5*envelope, -3*envelope)
        p['blink'] = blink(t, 4.8)
    elif name == 'thinking':
        p['head'][1] = c([(.95, 8), (2.7, 8), (4.1, 0)])
        p['head'][2] = c([(1.1, -3.5), (2.5, -3.5), (4.1, 0)])
        p['head'][0] = -2.5*envelope
        p['wrist_right'][1] = 4*envelope
        p['blink'] = blink(t, 1.7)
    elif name in ('celebrate', 'delight'):
        big = name == 'celebrate'
        lift = c([(.22, -2), (.9, 27 if big else 17), (1.85, 25 if big else 17), (d-.25, 0)])
        flex = c([(.27, 0), (1.08, 60 if big else 38), (1.9, 60 if big else 35), (d-.2, 0)])
        arms(lift, flex, -5*envelope)
        p['head'][0] = c([(.55, 3), (1.05, -4), (1.6, 2), (2.15, -2), (d-.2, 0)])
        p['head_t'][1] += c([(.25, -.003), (1, .01), (1.55, .003), (2.05, .008), (d-.15, 0)])
        p['blink'] = .65*blink(t, 1.15, .13)
    elif name == 'breathe':
        b = smooth(t) if t <= 1 else 1-smooth(t-1)
        p['chest_s'] = [1+.04*b, 1+.025*b, 1+.05*b]
        p['head_t'][1] = .015*b
        p['head'][0] = 1.5*b
        arms(9*b, 16*b, -3*b)
        p['blink'] = .18*b
    elif name == 'curious':
        p['head'][1] = c([(1.2, 9), (2.5, 9), (4.1, -7), (5.2, -7), (6.9, 0)])
        p['head'][2] = c([(1.5, -4), (2.7, -4), (4.5, 5), (5.3, 5), (6.9, 0)])
        p['head_t'][2] = .005*envelope
        p['blink'] = max(blink(t, 3.2), blink(t, 6.0))
    elif name == 'cozy':
        p['head'][0] = c([(2, 3), (4.1, 3), (6.9, 0)])
        p['head'][2] = 2*envelope
        p['chest_t'][1] = -.003*envelope
        p['blink'] = .92*blink(t, 3.3, .55)
        arms(-1.8*envelope, 3*envelope)
    elif name == 'acknowledge':
        p['head'][0] = c([(.3, -1.5), (.85, 7), (1.6, -1), (2.4, 0)])
        p['head'][2] = 2*envelope
        p['blink'] = .65*blink(t, 1.65)
    elif name == 'reassure':
        p['head'][2] = c([(1.1, 6), (3.1, 6), (4.6, 0)])
        p['head'][0] = 3*envelope
        p['head_t'][2] = .016*envelope
        p['arm_right'] = [-7*envelope, 0, 12*envelope]
        p['elbow_right'][2] = 36*envelope
        p['wrist_right'][1] = 10*envelope
        p['blink'] = .8*blink(t, 2.8, .2)
    elif name == 'nuzzle':
        p['head'][2] = c([(.65, -3), (1.45, 9), (2.3, 9), (3.8, 0)])
        p['head'][0] = 4*envelope
        p['head_t'][2] = .025*envelope
        p['blink'] = blink(t, 1.25, .8)
        arms(3*envelope, 8*envelope, -3*envelope)
    elif name == 'proud':
        p['head'][1] = c([(.9, 5), (1.8, -5), (2.8, 0)])
        p['head'][0] = -2.5*envelope
        p['chest_s'][1] += .012*envelope
        arms(10*envelope, 20*envelope)
        p['wrist_right'][2] = c([(.8, -4), (1.3, 6), (2.1, -2)])
        p['blink'] = .7*blink(t, 2.7)
    elif name == 'stretch':
        lift = c([(.5, -2), (2, 24), (3.2, 24), (5.3, 0)])
        arms(lift, 32*envelope, -5*envelope)
        p['elbow_left'][2] *= .72
        p['head'][2] = c([(1.7, -5), (3.1, 3), (5.3, 0)])
        p['head'][0] = -3*envelope
        p['head_t'][1] += .008*envelope
        p['blink'] = .8*blink(t, 2, .85)
    elif name == 'settle':
        p['head'][0] = c([(1.1, -2), (2.8, 4), (4.9, 0)])
        p['head'][2] = 2*envelope
        p['chest_s'] = [1+.015*envelope, 1+.008*envelope, 1+.018*envelope]
        p['blink'] = .95*blink(t, 1.5, 1.0)
        arms(3*envelope, 6*envelope)
    elif name == 'invite':
        p['arm_left'] = [-5*envelope, 0, -18*envelope]
        p['elbow_left'][2] = c([(.7, -42), (1.4, -30), (2.1, -42), (3.2, 0)])
        p['wrist_left'][1] = -12*envelope
        p['head'][2] = -3*envelope
        p['head'][0] = c([(.65, -1), (1.5, 4), (2.4, 0)])
        p['blink'] = blink(t, 2.65)
    return p


def quaternion(xyz):
    x, y, z = [math.radians(v)/2 for v in xyz]
    cx, cy, cz = math.cos(x), math.cos(y), math.cos(z)
    sx, sy, sz = math.sin(x), math.sin(y), math.sin(z)
    return [sx*cy*cz-cx*sy*sz, cx*sy*cz+sx*cy*sz,
            cx*cy*sz-sx*sy*cz, cx*cy*cz+sx*sy*sz]


def remove_animations(g, data):
    """Compact old curves, including unreferenced buffers left by old exporters."""
    g['animations'] = []
    used = set()
    for mesh in g['meshes']:
        for p in mesh['primitives']:
            used.update(p['attributes'].values())
            if 'indices' in p:
                used.add(p['indices'])
            for target in p.get('targets', []):
                used.update(target.values())
    for skin in g.get('skins', []):
        used.add(skin['inverseBindMatrices'])
    mapping = {old: new for new, old in enumerate(sorted(used))}
    for mesh in g['meshes']:
        for p in mesh['primitives']:
            p['attributes'] = {k: mapping[v] for k, v in p['attributes'].items()}
            if 'indices' in p:
                p['indices'] = mapping[p['indices']]
            p['targets'] = [{k: mapping[v] for k, v in t.items()} for t in p.get('targets', [])]
            if not p['targets']:
                del p['targets']
    for skin in g.get('skins', []):
        skin['inverseBindMatrices'] = mapping[skin['inverseBindMatrices']]
    g['accessors'] = [g['accessors'][i] for i in sorted(used)]
    assert not any('sparse' in a for a in g['accessors']), 'Unexpected sparse rig'
    views = {a['bufferView'] for a in g['accessors']}
    views.update(i['bufferView'] for i in g['images'])
    view_map = {old: new for new, old in enumerate(sorted(views))}
    binary = bytearray()
    new_views = []
    for i in sorted(views):
        view = copy.deepcopy(g['bufferViews'][i])
        start = view.get('byteOffset', 0)
        binary.extend(b'\0'*(-len(binary) % 4))
        view['byteOffset'] = len(binary)
        binary.extend(data[start:start+view['byteLength']])
        new_views.append(view)
    for a in g['accessors']:
        a['bufferView'] = view_map[a['bufferView']]
    for i in g['images']:
        i['bufferView'] = view_map[i['bufferView']]
    g['bufferViews'] = new_views
    return binary


def build():
    g, data = read_glb(ASSET)
    data = remove_animations(g, data)
    geometry_hash = hashlib.sha256(data).hexdigest()
    names = {n.get('name'): i for i, n in enumerate(g['nodes'])}
    def accessor(values, kind, bounds=False):
        width = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}[kind]
        flat = [v for row in values for v in row]
        binary = struct.pack('<'+'f'*len(flat), *flat)
        data.extend(b'\0'*(-len(data) % 4))
        view = len(g['bufferViews'])
        g['bufferViews'].append({'buffer': 0, 'byteOffset': len(data), 'byteLength': len(binary)})
        data.extend(binary)
        item = {'bufferView': view, 'componentType': 5126, 'count': len(flat)//width, 'type': kind}
        if bounds:
            item.update(min=[min(flat)], max=[max(flat)])
        g['accessors'].append(item)
        return len(g['accessors'])-1
    for name, (label, duration, mode, description) in CLIPS.items():
        times = [i/FPS for i in range(round(duration*FPS)+1)]
        poses = [pose(name, t) for t in times]
        for t, p in zip(times, poses):
            lag = pose(name, max(0, t-.10))['head'][2]
            taper = math.sin(math.pi*t/duration)**2
            p['ear_left'][2] = -.22*lag*taper
            p['ear_right'][2] = -.16*lag*taper
        anim = {'name': name, 'samplers': [], 'channels': [],
                'extras': {'label': label, 'duration': duration, 'mode': mode, 'description': description}}
        time_id = accessor([[t] for t in times], 'SCALAR', True)
        def channel(node, path, values, kind):
            anim['channels'].append({'sampler': len(anim['samplers']), 'target': {'node': node, 'path': path}})
            anim['samplers'].append({'input': time_id, 'output': accessor(values, kind), 'interpolation': 'LINEAR'})
        for control in ('head', 'arm_right', 'arm_left', 'elbow_right', 'elbow_left',
                        'wrist_right', 'wrist_left', 'ear_left', 'ear_right'):
            channel(names['CTRL_'+control], 'rotation', [quaternion(p[control]) for p in poses], 'VEC4')
        for control in ('head', 'chest'):
            node = names['CTRL_'+control]
            origin = g['nodes'][node]['translation']
            channel(node, 'translation', [[a+b for a, b in zip(origin, p[control+'_t'])] for p in poses], 'VEC3')
        channel(names['CTRL_chest'], 'scale', [p['chest_s'] for p in poses], 'VEC3')
        weights = [[min(2*p['blink'], 2-2*p['blink']), max(2*p['blink']-1, 0)] for p in poses]
        for key, node in names.items():
            if key and key.startswith('LID_'):
                channel(node, 'weights', weights, 'SCALAR')
        g['animations'].append(anim)
    g['buffers'] = [{'byteLength': len(data)}]
    g.setdefault('asset', {})['generator'] = 'Elyrii Velours motion library / 2026-09'
    encoded = json.dumps(g, separators=(',', ':')).encode()
    encoded += b' '*(-len(encoded) % 4)
    data.extend(b'\0'*(-len(data) % 4))
    raw = struct.pack('<4sII', b'glTF', 2, 28+len(encoded)+len(data))
    raw += struct.pack('<I4s', len(encoded), b'JSON')+encoded
    raw += struct.pack('<I4s', len(data), b'BIN\0')+data
    ASSET.write_bytes(raw)
    catalog = {a['name']: a['extras'] for a in g['animations']}
    (Path(__file__).parent/'clips.json').write_text(json.dumps(catalog, indent=2, ensure_ascii=False)+'\n')
    print(json.dumps({'clips': len(CLIPS), 'bytes': len(raw), 'geometry_sha256': geometry_hash,
                      'asset_sha256': hashlib.sha256(raw).hexdigest()}, indent=2))


if __name__ == '__main__':
    build()
