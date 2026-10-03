"""Build the 12 original Velours accessories, precisely fitted to its rest pose.

Requires Blender 4+. The original mascot is read only. Run from any directory:
  blender --background --python scripts/mascot/build_accessories.py
Add `-- --preview` to render front/three-quarter PNGs. Then compose the sheet:
  python3 scripts/mascot/render_accessory_contact_sheet.py
Use `-- --preview --preview-ids sleep_mask` to rerender a subset for fit review.
Meshes are exported in global glTF coordinates (metres, Y up, front +Z).
The wardrobe merger attaches them to the declared animation control using its
inverse world transform, so accessories follow the existing rig naturally.
"""
from pathlib import Path
import json
import math
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'elyrii_app/assets/elyrii_velours_animations.glb'
OUT = ROOT / 'elyrii_app/assets/accessories'
META = ROOT / 'scripts/mascot/accessories.json'
PREVIEWS = ROOT / 'scripts/mascot/previews'
TAU = math.tau

CATALOG = [
    ('beret', 'CTRL_head', 'Béret sauge', 'Un petit béret incliné entre les oreilles, avec son bouton crème.'),
    ('beanie', 'CTRL_head', 'Bonnet douillet', 'Un bonnet lavande à revers doux et pompon crème.'),
    ('flower_crown', 'CTRL_head', 'Couronne de fleurs', 'Cinq fleurs crème et rose sur une fine tige de sauge.'),
    ('star_crown', 'CTRL_head', 'Couronne d’étoiles', 'Trois étoiles arrondies sur un bandeau doré discret.'),
    ('moon_pin', 'CTRL_head', 'Broche lunaire', 'Une lune dorée et une petite étoile posées sur la tempe.'),
    ('round_glasses', 'CTRL_head', 'Lunettes rondes', 'Des montures rondes couleur prune qui laissent le regard libre.'),
    ('headphones', 'CTRL_head', 'Casque pastel', 'Des coussinets lavande, un arceau crème et deux touches dorées.'),
    ('sleep_mask', 'CTRL_head', 'Masque de repos', 'Un masque lavande avec deux paupières brodées pour le repos.'),
    ('cozy_scarf', 'CTRL_chest', 'Écharpe cocon', 'Une écharpe rose tendre avec deux pans et de petites franges.'),
    ('bow_tie', 'CTRL_chest', 'Nœud papillon', 'Un nœud prune aux ailes rondes, posé juste sous le menton.'),
    ('leaf_pendant', 'CTRL_chest', 'Pendentif feuille', 'Une feuille de sauge et sa nervure dorée, sur un cordon crème.'),
    ('mini_backpack', 'CTRL_chest', 'Petit sac à dos', 'Un petit sac sauge à rabat crème, poche et bretelles roses.'),
]


def bpos(p):
    """glTF Y-up vector to Blender Z-up."""
    return (p[0], -p[2], p[1])


def gpos(p):
    return (p[0], p[2], -p[1])


def material(name, color, metallic=0., roughness=.78):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.)
    mat.use_nodes = True
    principled = mat.node_tree.nodes.get('Principled BSDF')
    principled.inputs['Base Color'].default_value = (*color, 1.)
    principled.inputs['Roughness'].default_value = roughness
    principled.inputs['Metallic'].default_value = metallic
    return mat


PALETTE = {}
CURRENT = []
HEAD_BVH = None
CHEST_BVH = None
FACE_BVH = None


def front(x, y, surface='head'):
    bvh = {'head':HEAD_BVH,'chest':CHEST_BVH,'face':FACE_BVH}[surface]
    hit, _, _, _ = bvh.ray_cast(Vector((x, y, 1.2)), Vector((0., 0., -1.)), 3.)
    return hit.z if hit else (.28 if surface == 'head' else .20)


def mesh(name, vertices, faces, mat, smooth=True):
    data = bpy.data.meshes.new(name)
    data.from_pydata([bpos(v) for v in vertices], [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(PALETTE[mat])
    for poly in obj.data.polygons:
        poly.use_smooth = smooth
    CURRENT.append(obj)
    return obj


def ellipsoid(name, center, radii, mat, segments=12, rings=6):
    vertices = [(center[0], center[1]+radii[1], center[2])]
    for j in range(1, rings):
        a = math.pi*j/rings
        for i in range(segments):
            t = TAU*i/segments
            vertices.append((center[0]+radii[0]*math.sin(a)*math.cos(t),
                             center[1]+radii[1]*math.cos(a),
                             center[2]+radii[2]*math.sin(a)*math.sin(t)))
    bottom = len(vertices)
    vertices.append((center[0], center[1]-radii[1], center[2]))
    faces = [(0, 1+i, 1+(i+1)%segments) for i in range(segments)]
    for j in range(rings-2):
        for i in range(segments):
            a = 1+j*segments+i
            b = 1+j*segments+(i+1)%segments
            faces.append((a, a+segments, b+segments, b))
    faces.extend((bottom, bottom-segments+(i+1)%segments, bottom-segments+i) for i in range(segments))
    return mesh(name, vertices, [tuple(reversed(face)) for face in faces], mat)


def tube(name, points, radius, mat, sides=6, closed=False):
    points = [Vector(p) for p in points]
    vertices = []
    for i, p in enumerate(points):
        a = points[(i-1)%len(points)] if (i or closed) else p
        b = points[(i+1)%len(points)] if (i<len(points)-1 or closed) else p
        tangent = (b-a).normalized()
        ref = Vector((0, 0, 1)) if abs(tangent.z) < .95 else Vector((0, 1, 0))
        u = tangent.cross(ref).normalized()
        v = tangent.cross(u).normalized()
        vertices.extend(tuple(p+radius*(math.cos(TAU*j/sides)*u+math.sin(TAU*j/sides)*v)) for j in range(sides))
    faces = []
    for i in range(len(points) if closed else len(points)-1):
        n = (i+1)%len(points)
        for j in range(sides):
            faces.append((i*sides+j, i*sides+(j+1)%sides, n*sides+(j+1)%sides, n*sides+j))
    if not closed:
        faces.extend((tuple(reversed(range(sides))), tuple((len(points)-1)*sides+j for j in range(sides))))
    return mesh(name, vertices, faces, mat)


def loop(name, center, rx, rz, radius, mat, steps=32, y_wave=0.):
    return tube(name, [(center[0]+rx*math.cos(TAU*i/steps), center[1]+y_wave*math.sin(TAU*i/steps),
                        center[2]+rz*math.sin(TAU*i/steps)) for i in range(steps)], radius, mat, closed=True)


def shell(name, center, profile, mat, segments=28):
    vertices = []
    for rx, ry, rz in profile:
        vertices.extend((center[0]+rx*math.cos(TAU*i/segments), center[1]+ry,
                         center[2]+rz*math.sin(TAU*i/segments)) for i in range(segments))
    faces = []
    for j in range(len(profile)-1):
        for i in range(segments):
            a=j*segments+i; b=j*segments+(i+1)%segments
            faces.append((a,b,b+segments,a+segments))
    faces.extend((tuple(reversed(range(segments))), tuple((len(profile)-1)*segments+i for i in range(segments))))
    return mesh(name, vertices, [tuple(reversed(face)) for face in faces], mat)


def rounded_box(name, center, dimensions, radius, mat, rotation=0.):
    bpy.ops.mesh.primitive_cube_add(size=1, location=bpos(center))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (dimensions[0], dimensions[2], dimensions[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler[1] = -rotation
    obj.data.materials.append(PALETTE[mat])
    bevel = obj.modifiers.new('Soft textile corners', 'BEVEL')
    bevel.width=radius; bevel.segments=3
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    for face in obj.data.polygons:
        face.use_smooth=True
    obj.modifiers.new('Soft weighted normals', 'WEIGHTED_NORMAL')
    CURRENT.append(obj)
    return obj


def badge(name, outline, z, thickness, mat, bevel=.007, conform=None):
    depths=[front(x,y)+conform if conform is not None else z for x,y in outline]
    vertices = [(x,y,d-thickness/2) for (x,y),d in zip(outline,depths)]+[(x,y,d+thickness/2) for (x,y),d in zip(outline,depths)]
    n=len(outline)
    faces=[tuple(reversed(range(n))), tuple(n+i for i in range(n))]
    faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    obj=mesh(name,vertices,faces,mat,False)
    modifier=obj.modifiers.new('Rounded embroidery edge','BEVEL')
    modifier.width=bevel; modifier.segments=2
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.modifiers.new('Balanced badge normals','WEIGHTED_NORMAL')
    return obj


def star(name, center, radius, mat, rotation=0.):
    points=[]
    for i in range(10):
        a=math.pi/2+rotation+TAU*i/10
        r=radius if i%2==0 else radius*.48
        points.append((center[0]+r*math.cos(a),center[1]+r*math.sin(a)))
    return badge(name,points,center[2],.021,mat,bevel=.006,conform=.043)


def beret():
    shell('Sage felt beret',(0.,1.695,-.035),[(.235,0.,.218),(.285,.038,.255),(.282,.088,.251),(.20,.139,.18),(.07,.165,.065),(.006,.171,.006)],'sage')
    loop('Plum beret piping',(0.,1.702,-.035),.239,.223,.011,'plum',28)
    ellipsoid('Cream beret button',(-.01,1.890,-.04),(.021,.030,.021),'cream',10,5)


def beanie():
    shell('Lavender knit dome',(0.,1.682,-.055),[(.252,0.,.226),(.275,.057,.246),(.24,.145,.219),(.158,.222,.146),(.04,.26,.037),(.004,.265,.004)],'lavender')
    loop('Cream knit rolled brim',(0.,1.708,-.055),.263,.238,.031,'cream',28)
    for k in range(7):
        t=TAU*k/7
        points=[]
        for j in range(10):
            a=(math.pi/2)*j/10
            points.append((.267*math.cos(a)*math.cos(t),1.711+.235*math.sin(a),-.055+.243*math.cos(a)*math.sin(t)))
        tube('Knit rib %02d'%k,points,.005,'lavender_dark',sides=4)
    ellipsoid('Fluffy cream pompom',(0.,1.998,-.055),(.064,.064,.064),'cream',16,8)


def flower_crown():
    points=[]
    for i in range(29):
        x=-.43+.86*i/28
        y=1.535+.018*(1-(x/.43)**2)
        points.append((x,y,front(x,y)+.022))
    tube('Sage flower stem',points,.014,'sage')
    for k,x in enumerate([-.36,-.18,0.,.18,.36]):
        y=1.55+.015*(1-(x/.43)**2)
        z=front(x,y)+.039
        for j in range(5):
            t=TAU*j/5+math.pi/2
            ellipsoid('Petal %d %d'%(k,j),(x+.038*math.cos(t),y+.038*math.sin(t),z),(.036,.037,.012),'rose' if k%2 else 'cream',8,4)
        ellipsoid('Gold flower heart %d'%k,(x,y,z+.014),(.019,.019,.014),'gold',8,4)
        if k<4:
            ellipsoid('Sage little leaf %d'%k,(x+.077,y-.025,z-.007),(.032,.015,.009),'sage',8,4)


def star_crown():
    points=[]
    for i in range(29):
        x=-.40+.80*i/28; y=1.515+.025*(1-(x/.4)**2)
        points.append((x,y,front(x,y)+.024))
    tube('Quiet gold crown band',points,.014,'gold')
    for k,x in enumerate([-.265,0.,.265]):
        y=1.585 if k!=1 else 1.625
        z=front(x,y)+.043
        star('Rounded crown star %d'%k,(x,y,z),.071 if k!=1 else .088,'gold')
        tube('Star stem %d'%k,[(x,1.54,front(x,1.54)+.026),(x,y-.035,z)],.009,'gold')


def moon_pin():
    cx,cy=-.405,1.477
    z=front(cx,cy)+.05
    # A single closed crescent outline, with generous soft tips.
    outer=[(cx+.082*math.cos(math.radians(55+250*i/24)),cy+.082*math.sin(math.radians(55+250*i/24))) for i in range(25)]
    top,bottom=outer[0],outer[-1]
    inner=[]
    for i in range(1,24):
        t=i/24
        y=bottom[1]+(top[1]-bottom[1])*t
        x=cx+.047-.080*math.sin(math.pi*t)
        inner.append((x,y))
    badge('Butter gold moon brooch',outer+inner,max(front(x,y) for x,y in outer+inner)+.025,.024,'gold',.004)
    star('Small cream companion star',(cx+.104,cy+.056,z+.005),.033,'cream',-.16)


def round_glasses():
    for k,(cx,cy) in enumerate([(-.242,1.207),(.243,1.235)]):
        points=[]
        for i in range(32):
            a=TAU*i/32
            x=cx+.171*math.cos(a); y=cy+.186*math.sin(a)
            points.append((x,y,front(x,y,'face')+.023))
        tube('Round plum rim %d'%k,points,.012,'plum',closed=True)
        s=-1 if k==0 else 1
        tube('Curved glasses temple %d'%k,[(cx+s*.171,cy,front(cx+s*.171,cy,'face')+.021),(s*.46,cy+.025,.255),(s*.505,cy+.06,.10),(s*.49,cy+.07,-.10)],.009,'plum')
    tube('Gently arched bridge',[(-.073,1.256,front(-.073,1.256)+.029),(-.036,1.285,front(-.036,1.285)+.029),(.008,1.29,front(.008,1.29)+.029),(.073,1.281,front(.073,1.281)+.029)],.01,'gold')


def headphones():
    points=[(.56*math.cos(math.pi*i/32),1.32+.43*math.sin(math.pi*i/32),-.233) for i in range(33)]
    tube('Cream headphone arch',points,.026,'cream',sides=8)
    tube('Lavender arch inset',[(x,y+.003,z-.022) for x,y,z in points],.008,'lavender',sides=5)
    for k,s in enumerate([-1,1]):
        ellipsoid('Cream ear cushion %d'%k,(s*.543,1.30,-.040),(.057,.139,.115),'cream',12,7)
        ellipsoid('Lavender ear cup %d'%k,(s*.59,1.30,-.040),(.048,.131,.105),'lavender',12,7)
        ellipsoid('Gold cup button %d'%k,(s*.63,1.30,-.020),(.012,.037,.037),'gold',10,5)
        tube('Headphone hinge %d'%k,[(s*.555,1.365,-.233),(s*.582,1.36,-.13),(s*.59,1.34,-.10)],.018,'lavender',sides=6)


def mask_patch(name,cx,cy,rx,ry):
    segments=28; rings=4
    vertices=[(cx,cy,max(.436,front(cx,cy,'face'))+.060)]
    for j in range(1,rings+1):
        r=j/rings
        for i in range(segments):
            a=TAU*i/segments; x=cx+rx*r*math.cos(a); y=cy+ry*r*math.sin(a)
            vertices.append((x,y,max(.436,front(x,y,'face'))+.028+.032*(1-r*r)))
    faces=[(0,1+i,1+(i+1)%segments) for i in range(segments)]
    for j in range(rings-1):
        for i in range(segments):
            a=1+j*segments+i;b=1+j*segments+(i+1)%segments
            faces.append((a,a+segments,b+segments,b))
    obj=mesh(name,vertices,faces,'lavender')
    solid=obj.modifiers.new('Padded mask thickness','SOLIDIFY');solid.thickness=.015
    bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=solid.name)


def sleep_mask():
    # The strap passes around the sides and back; no extra line across the face.
    points=[]
    for i in range(35):
        a=math.radians(10+160*i/34)
        points.append((.547*math.cos(a),1.228,-.051-.492*math.sin(a)))
    tube('Rose sleep mask elastic',points,.018,'rose',sides=6)
    for k,(cx,cy) in enumerate([(-.242,1.207),(.243,1.235)]):
        mask_patch('Padded sleeping mask %d'%k,cx,cy,.193,.180)
        points=[]
        for i in range(13):
            x=cx-.095+.19*i/12;y=cy-.020-.034*math.sin(math.pi*i/12)
            points.append((x,y,max(.436,front(x,y,'face'))+.070))
        tube('Embroidered sleeping eye %d'%k,points,.008,'plum',sides=5)
    rounded_box('Soft mask nose bridge',(0.,1.285,front(0.,1.285)+.057),(.157,.102,.026),.018,'lavender',rotation=.04)


def cozy_scarf():
    loop('Rose scarf wrap',(0.,.715,-.018),.274,.315,.044,'rose',32,y_wave=-.012)
    loop('Rose lower scarf fold',(0.,.685,-.018),.265,.30,.029,'rose_dark',32,y_wave=-.012)
    rounded_box('Long scarf tail',(-.162,.539,.279),(.10,.302,.043),.022,'rose',rotation=-.10)
    rounded_box('Short scarf tail',(-.070,.577,.291),(.086,.205,.047),.020,'rose',rotation=.12)
    for k,x in enumerate([-.191,-.163,-.135]):
        tube('Long scarf fringe %d'%k,[(x,.403,.282),(x-.004,.367,.286)],.008,'rose_dark',sides=5)
    for k,x in enumerate([-.093,-.065,-.040]):
        tube('Short scarf fringe %d'%k,[(x,.487,.296),(x+.003,.459,.299)],.007,'rose_dark',sides=5)


def bow_tie():
    loop('Cream bow collar',(0.,.710,-.030),.247,.280,.012,'cream',28)
    left=[(-.016,.715),(-.111,.770),(-.166,.752),(-.170,.664),(-.131,.641),(-.019,.692)]
    right=[(.016,.715),(.111,.770),(.166,.752),(.170,.664),(.131,.641),(.019,.692)]
    badge('Plum bow left wing',left,.306,.050,'plum',.018)
    badge('Plum bow right wing',right,.306,.050,'plum',.018)
    ellipsoid('Rose bow knot',(0.,.706,.324),(.033,.041,.036),'rose',12,6)
    tube('Left bow fold',[(-.126,.718,.341),(-.051,.705,.344)],.006,'rose_dark',sides=5)
    tube('Right bow fold',[(.126,.718,.341),(.051,.705,.344)],.006,'rose_dark',sides=5)


def leaf_pendant():
    points=[(-.247,.714,-.03),(-.209,.697,.14),(-.133,.674,.209),(0.,.631,.279),(.133,.674,.209),(.209,.697,.14),(.247,.714,-.03)]
    tube('Cream pendant cord',points,.010,'cream',sides=6)
    tube('Pendant clasp loop',[(0.,.637,.29),(0.,.617,.309)],.008,'gold',sides=6)
    # Soft asymmetric leaf outline, sized to preserve the white tummy patch.
    outline=[(0.,.625),(-.035,.601),(-.052,.557),(-.046,.526),(-.012,.482),(.026,.508),(.048,.548),(.034,.589)]
    badge('Sage leaf pendant',outline,.314,.025,'sage',.010)
    tube('Gold leaf vein',[(0.,.611,.335),(-.007,.567,.336),(-.004,.532,.336),(-.011,.497,.333)],.004,'gold',sides=5)
    tube('Leaf branch left',[(-.006,.563,.336),(-.034,.580,.336)],.003,'gold',sides=4)
    tube('Leaf branch right',[(-.004,.540,.336),(.027,.558,.336)],.003,'gold',sides=4)


def mini_backpack():
    rounded_box('Sage backpack body',(0.,.485,-.374),(.325,.376,.148),.049,'sage')
    rounded_box('Cream backpack flap',(0.,.640,-.408),(.324,.151,.061),.036,'cream')
    rounded_box('Rose backpack pocket',(0.,.414,-.469),(.195,.127,.035),.024,'rose')
    ellipsoid('Gold backpack clasp',(0.,.580,-.451),(.018,.026,.010),'gold',10,5)
    tube('Backpack carry handle',[(-.08,.676,-.354),(-.07,.715,-.346),(0.,.738,-.339),(.07,.715,-.346),(.08,.676,-.354)],.012,'rose_dark',sides=6)
    for k,s in enumerate([-1,1]):
        points=[(s*.115,.620,-.353),(s*.165,.703,-.239),(s*.206,.721,-.090),(s*.227,.681,.095),(s*.222,.569,.201),(s*.219,.434,.205),(s*.216,.397,.137),(s*.187,.383,-.118),(s*.119,.334,-.345)]
        tube('Rose shoulder strap %d'%k,points,.022,'rose',sides=8)
        rounded_box('Gold strap buckle %d'%k,(s*.218,.445,.222),(.030,.041,.015),.006,'gold')


def bvh_for(objects):
    if not isinstance(objects,list):objects=[objects]
    deps=bpy.context.evaluated_depsgraph_get()
    vertices=[];polygons=[]
    for obj in objects:
        evaluated=obj.evaluated_get(deps);data=evaluated.to_mesh();offset=len(vertices)
        vertices.extend(Vector(gpos(obj.matrix_world @ v.co)) for v in data.vertices)
        polygons.extend(tuple(offset+i for i in p.vertices) for p in data.polygons)
        evaluated.to_mesh_clear()
    return BVHTree.FromPolygons(vertices,polygons)


def camera_for(name,position,target,scale):
    data=bpy.data.cameras.new(name);obj=bpy.data.objects.new(name,data)
    bpy.context.collection.objects.link(obj)
    obj.location=bpos(position)
    obj.rotation_euler=(Vector(bpos(target))-obj.location).to_track_quat('-Z','Y').to_euler()
    data.type='ORTHO';data.ortho_scale=scale
    return obj


def preview_scene():
    scene=bpy.context.scene
    scene.render.engine='CYCLES';scene.cycles.samples=24
    scene.cycles.use_denoising=True
    scene.render.resolution_x=500;scene.render.resolution_y=600;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'
    scene.world=bpy.data.worlds.new('Velours accessory studio')
    scene.world.color=(.17,.16,.15)
    scene.view_settings.view_transform='AgX'
    for name,pos,power,size in [('Soft key',(-2.4,3.9,3.0),380,4.),('Gentle fill',(2.8,2.4,2.0),220,3.),('Cream rim',(-1.5,3.,-2.),360,3.)]:
        data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
        obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj);obj.location=bpos(pos)
        obj.rotation_euler=(Vector(bpos((0.,1.,0.)))-obj.location).to_track_quat('-Z','Y').to_euler()
    scene.render.film_transparent=True
    return camera_for('Accessory portrait',(0.,1.03,4.5),(0.,1.03,0.),2.18),camera_for('Backpack portrait',(2.2,1.4,-3.),(0.,.93,0.),2.18)


def export(accessory_id,objects):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    path=OUT/(accessory_id+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False,export_apply=True,export_extras=True)
    triangles=0;vertices=[]
    for obj in objects:
        evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());data=evaluated.to_mesh();data.calc_loop_triangles()
        triangles+=len(data.loop_triangles)
        vertices.extend(gpos(obj.matrix_world @ v.co) for v in data.vertices)
        evaluated.to_mesh_clear()
    return triangles,{'min':[round(min(p[i] for p in vertices),6) for i in range(3)],'max':[round(max(p[i] for p in vertices),6) for i in range(3)]}


def main():
    global HEAD_BVH,CHEST_BVH,FACE_BVH
    preview='--preview' in sys.argv
    preview_ids=None
    if '--preview-ids' in sys.argv:
        preview_ids=set(sys.argv[sys.argv.index('--preview-ids')+1].split(','))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()
    base=list(bpy.context.scene.objects)
    head=bpy.data.objects.get('root.0');chest=bpy.data.objects.get('root.1')
    if not head or not chest:
        raise RuntimeError('Velours rest-pose mesh names changed; inspect fit before rebuilding.')
    HEAD_BVH=bvh_for(head);CHEST_BVH=bvh_for(chest)
    FACE_BVH=bvh_for([head,bpy.data.objects['root.8'],bpy.data.objects['root.10'],bpy.data.objects['root.11']])
    for name,color,metal,roughness in [
        ('cream',(.89,.83,.71),0.,.85),('plum',(.18,.050,.14),0.,.78),
        ('rose',(.70,.36,.39),0.,.84),('rose_dark',(.55,.25,.31),0.,.86),
        ('sage',(.39,.55,.43),0.,.87),('lavender',(.56,.48,.68),0.,.83),
        ('lavender_dark',(.46,.37,.57),0.,.85),('gold',(.73,.55,.25),.28,.56)]:
        PALETTE[name]=material('Velours accessory '+name,color,metal,roughness)
    OUT.mkdir(parents=True,exist_ok=True)
    records=[];all_sets={}
    for accessory_id,parent,label,description in CATALOG:
        CURRENT.clear()
        globals()[accessory_id]()
        objects=list(CURRENT)
        for obj in objects:
            obj['accessory']=accessory_id;obj['attachmentControl']=parent
        triangles,bounds=export(accessory_id,objects)
        records.append({'id':accessory_id,'parent':parent,'asset':'assets/accessories/'+accessory_id+'.glb','labelFr':label,'descriptionFr':description,'triangles':triangles,'bounds':bounds})
        all_sets[accessory_id]=objects
        for obj in objects:obj.hide_render=True
        print(accessory_id,triangles,bounds)
    META.write_text(json.dumps({'schemaVersion':1,'coordinateSpace':'gltf-global-y-up-front-positive-z','source':'assets/elyrii_velours_animations.glb','accessories':records},ensure_ascii=False,indent=2)+'\n')
    if preview:
        PREVIEWS.mkdir(parents=True,exist_ok=True)
        front_camera,back_camera=preview_scene()
        scene=bpy.context.scene
        for accessory_id,objects in all_sets.items():
            if preview_ids is not None and accessory_id not in preview_ids:continue
            for obj in objects:obj.hide_render=False
            scene.camera=back_camera if accessory_id=='mini_backpack' else front_camera
            scene.render.filepath=str(PREVIEWS/(accessory_id+'.png'))
            bpy.ops.render.render(write_still=True)
            if accessory_id=='mini_backpack':
                scene.camera=front_camera;scene.render.filepath=str(PREVIEWS/'mini_backpack_front.png');bpy.ops.render.render(write_still=True)
            for obj in objects:obj.hide_render=True
    print('Created',len(records),'accessories;',sum(r['triangles'] for r in records),'triangles total.')


if __name__=='__main__':
    main()
