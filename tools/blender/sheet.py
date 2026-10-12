# blender -b -P sheet.py -- in.glb out_dir [frac] [view]
import bpy, sys, math, mathutils, os
argv = sys.argv[sys.argv.index("--") + 1:]
src, outd = argv[0], argv[1]
frac = float(argv[2]) if len(argv) > 2 else 0.5
view = float(argv[3]) if len(argv) > 3 else 60
os.makedirs(outd, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
scn = bpy.context.scene
arm = next(o for o in scn.objects if o.type == 'ARMATURE')
scn.render.engine = 'BLENDER_EEVEE_NEXT'
scn.render.resolution_x = 240; scn.render.resolution_y = 300
w = bpy.data.worlds.new("w"); scn.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.4, 0.4, 0.45, 1)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); scn.collection.objects.link(cam); scn.camera = cam
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", 'SUN')); scn.collection.objects.link(sun); sun.data.energy = 3
sun.rotation_euler = (math.radians(50), 0, math.radians(30))
h = max((arm.matrix_world @ b.head_local).z for b in arm.data.bones)
c = mathutils.Vector((0, 0, h * 0.45))
a = math.radians(view)
d = h * 2.6
cam.location = c + mathutils.Vector((math.sin(a) * d, -math.cos(a) * d, h * 0.15))
cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
for t in list(arm.animation_data.nla_tracks):
    arm.animation_data.nla_tracks.remove(t)
for act in list(bpy.data.actions):
    arm.animation_data.action = act
    f0, f1 = act.frame_range
    scn.frame_set(int(f0 + (f1 - f0) * frac))
    scn.render.filepath = os.path.join(outd, act.name.split("_Armature")[0] + ".png")
    bpy.ops.render.render(write_still=True)
