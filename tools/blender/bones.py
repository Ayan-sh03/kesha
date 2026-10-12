import bpy, sys
argv = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
p = argv[0]
if p.endswith(".fbx"):
    bpy.ops.import_scene.fbx(filepath=p)
else:
    bpy.ops.import_scene.gltf(filepath=p)
for o in bpy.context.scene.objects:
    if o.type == 'ARMATURE':
        print("ARM", o.name, len(o.data.bones), "bones")
        print("BONES", [b.name for b in o.data.bones])
    if o.type == 'MESH':
        print("MESH", o.name, len(o.data.polygons), "vgroups", len(o.vertex_groups))
for a in bpy.data.actions:
    print("ACTION", a.name, a.frame_range[:], len(a.fcurves))
