# blender -b -P preview.py -- in.glb out_prefix
import bpy, sys, math, mathutils
argv = sys.argv[sys.argv.index("--") + 1:]
src, out = argv[0], argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
objs = [o for o in bpy.context.scene.objects if o.type == 'MESH']
mn = mathutils.Vector((1e9,)*3); mx = mathutils.Vector((-1e9,)*3)
for o in objs:
    for v in o.bound_box:
        w = o.matrix_world @ mathutils.Vector(v)
        mn = mathutils.Vector(map(min, mn, w)); mx = mathutils.Vector(map(max, mx, w))
c = (mn + mx) / 2; size = max(mx - mn)
print("BOUNDS", mn, mx, "faces", sum(len(o.data.polygons) for o in objs), "bones", [o.name for o in bpy.context.scene.objects if o.type=='ARMATURE'])
scn = bpy.context.scene
scn.render.engine = 'BLENDER_EEVEE_NEXT'
scn.render.resolution_x = 512; scn.render.resolution_y = 768
world = bpy.data.worlds.new("w"); scn.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.35, 0.35, 0.4, 1)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); scn.collection.objects.link(cam); scn.camera = cam
cam.data.lens = 50
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", 'SUN')); scn.collection.objects.link(sun)
sun.data.energy = 3; sun.rotation_euler = (math.radians(50), 0, math.radians(30))
for i, ang in enumerate([0, 90, 180]):
    a = math.radians(ang)
    d = size * 2.2
    cam.location = c + mathutils.Vector((math.sin(a) * d, -math.cos(a) * d, 0))
    direction = c - cam.location
    cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
    scn.render.filepath = f"{out}_{i}.png"
    bpy.ops.render.render(write_still=True)
