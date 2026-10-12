# blender -b -P anim_preview.py -- in.glb out_prefix action_name nframes [view_deg]
import bpy, sys, math, mathutils
argv = sys.argv[sys.argv.index("--") + 1:]
src, out, act_name, nf = argv[0], argv[1], argv[2], int(argv[3])
view = float(argv[4]) if len(argv) > 4 else 90
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
scn = bpy.context.scene
arm = next(o for o in scn.objects if o.type == 'ARMATURE')
act = next((a for a in bpy.data.actions if a.name == act_name), None) or next(a for a in bpy.data.actions if a.name.startswith(act_name))
print("ACTIONS", [a.name for a in bpy.data.actions])
if arm.animation_data is None: arm.animation_data_create()
for t in list(arm.animation_data.nla_tracks): arm.animation_data.nla_tracks.remove(t)
arm.animation_data.action = act
f0, f1 = act.frame_range
scn.render.engine = 'BLENDER_EEVEE_NEXT'
scn.render.resolution_x = 360; scn.render.resolution_y = 480
w = bpy.data.worlds.new("w"); scn.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.4, 0.4, 0.45, 1)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); scn.collection.objects.link(cam); scn.camera = cam
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", 'SUN')); scn.collection.objects.link(sun); sun.data.energy = 3
sun.rotation_euler = (math.radians(50), 0, math.radians(30))
a = math.radians(view)
c = mathutils.Vector((0, 0, 0.7))
cam.location = c + mathutils.Vector((math.sin(a) * 3.2, -math.cos(a) * 3.2, 0.2))
cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
for i in range(nf):
    f = f0 + (f1 - f0) * i / max(nf - 1, 1)
    scn.frame_set(int(round(f)))
    scn.render.filepath = f"{out}_{i}.png"
    bpy.ops.render.render(write_still=True)
