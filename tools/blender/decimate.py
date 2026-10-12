# blender -b -P decimate.py -- in.glb out.glb target_tris [height_m]
import bpy, sys, mathutils
argv = sys.argv[sys.argv.index("--") + 1:]
src, out, target = argv[0], argv[1], int(argv[2])
height = float(argv[3]) if len(argv) > 3 else 0.0
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
total = sum(len(o.data.polygons) for o in meshes)
for o in meshes:
    bpy.context.view_layer.objects.active = o
    m = o.modifiers.new("dec", 'DECIMATE')
    m.ratio = min(1.0, target / max(total, 1))
    bpy.ops.object.modifier_apply(modifier=m.name)
if height > 0:
    mn = min((o.matrix_world @ mathutils.Vector(v)).z for o in meshes for v in o.bound_box)
    mx = max((o.matrix_world @ mathutils.Vector(v)).z for o in meshes for v in o.bound_box)
    s = height / (mx - mn)
    for o in bpy.context.scene.objects:
        if o.parent is None:
            o.scale *= s
            o.location *= s
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mn = min((o.matrix_world @ mathutils.Vector(v)).z for o in meshes for v in o.bound_box)
    for o in bpy.context.scene.objects:
        if o.parent is None:
            o.location.z -= mn
print("TRIS", sum(len(o.data.polygons) for o in meshes))
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_image_format='JPEG', export_jpeg_quality=90)
