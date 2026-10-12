# Retarget Uthana/Mixamo motion clips onto a rigged character and bake them
# into one Godot-ready GLB.
#
#   blender -b -P retarget.py -- char.glb out.glb clips.json
#
# clips.json: [{"name": "run", "file": "motion.glb", "loop": true, "inplace": true,
#               "start": 0.0, "end": 1.0}]   (start/end are fractions of the clip)
#
# Method: for every bone, take the source pose's world rotation relative to the
# source rest, and apply that delta on top of the target's rest (so differing
# rest poses - T vs A pose - transfer correctly). Hips translation is scaled by
# leg length. Loops are found by searching for the best matching pose pair.
import bpy
import sys
import json
import math
from mathutils import Matrix, Quaternion, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
CHAR, OUT, CLIPS = argv[0], argv[1], json.load(open(argv[2]))

bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene
scn.render.fps = 30
bpy.ops.import_scene.gltf(filepath=CHAR)
tgt = next(o for o in scn.objects if o.type == 'ARMATURE')
tgt.animation_data_create()
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)

TB = tgt.data.bones
order = []


def walk(b):
    order.append(b.name)
    for c in b.children:
        walk(c)


for b in TB:
    if b.parent is None:
        walk(b)

t_rest_world = {n: (tgt.matrix_world @ TB[n].matrix_local) for n in order}
t_rest_q = {n: t_rest_world[n].to_quaternion() for n in order}
hips = order[0]
t_hips_h = t_rest_world[hips].translation.z - min((tgt.matrix_world @ TB[n].head_local).z for n in order)

KEY = ["mixamorig:LeftUpLeg", "mixamorig:LeftLeg", "mixamorig:RightUpLeg", "mixamorig:RightLeg",
       "mixamorig:LeftArm", "mixamorig:RightArm", "mixamorig:Spine1", "mixamorig:LeftForeArm", "mixamorig:RightForeArm"]


def yaw_of(q):
    f = q @ Vector((0, 0, 1))  # bone Y is along the bone; use a perpendicular for facing
    return math.atan2(f.x, f.y)


for clip in CLIPS:
    before = set(scn.objects)
    bpy.ops.import_scene.gltf(filepath=clip["file"])
    new = [o for o in scn.objects if o not in before]
    src = next(o for o in new if o.type == 'ARMATURE')
    act = src.animation_data.action
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    n_all = f1 - f0 + 1
    a0 = f0 + int(clip.get("start", 0.0) * (n_all - 1))
    a1 = f0 + int(clip.get("end", 1.0) * (n_all - 1))
    SB = src.data.bones
    s_rest_world = {b.name: (src.matrix_world @ b.matrix_local) for b in SB}
    s_hips_h = s_rest_world.get(hips, Matrix()).translation.z - min((src.matrix_world @ b.head_local).z for b in SB)
    scale = t_hips_h / max(s_hips_h, 1e-4)
    # sample source world rotations
    frames = list(range(a0, a1 + 1))
    samples = []
    for f in frames:
        scn.frame_set(f)
        d = {}
        for n in order:
            pb = src.pose.bones.get(n)
            if pb is None:
                continue
            w = src.matrix_world @ pb.matrix
            d[n] = (w.to_quaternion(), w.translation.copy())
        samples.append(d)
    # trim around the moment of peak motion (attacks, jumps, throws)
    if clip.get("trim_peak") and clip["trim_peak"] in samples[0]:
        bn = clip["trim_peak"]
        axis = clip.get("axis")
        sp = []
        for k in range(len(samples)):
            a_ = samples[max(0, k - 1)][bn][1]
            b_ = samples[min(len(samples) - 1, k + 1)][bn][1]
            v = (b_ - a_)
            sp.append(v.z if axis == "z" else v.length)
        pk = max(range(len(sp)), key=lambda k: sp[k])
        lo_ = max(0, pk - int(clip.get("pre", 0.3) * 30))
        hi_ = min(len(samples), pk + int(clip.get("post", 0.35) * 30) + 1)
        samples = samples[lo_:hi_]
        print("TRIM", clip["name"], lo_, pk, hi_)
    elif "start_s" in clip or "end_s" in clip:
        lo_ = int(clip.get("start_s", 0.0) * 30)
        hi_ = int(clip.get("end_s", len(samples) / 30.0) * 30)
        samples = samples[lo_:hi_]
    # yaw correction: make the clip face the same way as the rest pose on average
    yaw_fix = Quaternion()
    if clip.get("face_rest", True) and hips in samples[0]:
        deltas = []
        for s in samples:
            q = s[hips][0] @ s_rest_world[hips].to_quaternion().inverted()
            deltas.append(yaw_of(q))
        avg = math.atan2(sum(math.sin(y) for y in deltas), sum(math.cos(y) for y in deltas))
        yaw_fix = Quaternion((0, 0, 1), -avg)
    # loop: find best matching pose pair
    if clip.get("loop"):
        def feat(s):
            v = []
            for k in KEY:
                if k in s:
                    q = s[k][0]
                    v += [q.w, q.x, q.y, q.z]
            return v
        F = [feat(s) for s in samples]
        best = (1e9, 0, len(samples) - 1)
        lo = int(clip.get("min_len", 0.45) * 30)
        hi = int(clip.get("max_len", 2.2) * 30)
        for i in range(0, max(1, len(samples) - lo)):
            for j in range(i + lo, min(len(samples), i + hi)):
                d = sum((a - b) ** 2 for a, b in zip(F[i], F[j]))
                # prefer starting later (skip the clip's settling-in) and longer loops a bit
                d += 0.0005 * (j - i) ** -1
                if d < best[0]:
                    best = (d, i, j)
        _, i, j = best
        samples = samples[i:j + 1]
        print("LOOP", clip["name"], i, j, round(best[0], 4))
    # build the target action
    action = bpy.data.actions.new(clip["name"])
    tgt.animation_data.action = action
    root_start = samples[0][hips][1].copy() if hips in samples[0] else Vector()
    n = len(samples)
    for fi, s in enumerate(samples):
        if clip.get("loop") and fi == n - 1:
            s = samples[0]  # close the loop exactly
        arm_m = {}
        for name in order:
            pb = tgt.pose.bones[name]
            b = TB[name]
            if name in s and name in s_rest_world:
                q_src, p_src = s[name]
                delta = yaw_fix @ q_src @ s_rest_world[name].to_quaternion().inverted()
                q_world = delta @ t_rest_q[name]
            else:
                parent = b.parent.name if b.parent else None
                q_world = None
            # target bone world matrix
            if b.parent is None:
                pos = t_rest_world[name].translation.copy()
                if name in s:
                    d = yaw_fix @ (s[name][1] - root_start)
                    d *= scale
                    if clip.get("inplace", True):
                        d.x = 0.0
                        d.y = 0.0
                    if clip.get("inplace_z", False):
                        d.z = 0.0
                    pos += d
                if q_world is None:
                    q_world = t_rest_q[name]
                W = Matrix.LocRotScale(pos, q_world, Vector((1, 1, 1)))
            else:
                P = arm_m[b.parent.name]
                rel = b.parent.matrix_local.inverted() @ b.matrix_local
                head = (tgt.matrix_world @ P @ rel).translation
                if q_world is None:
                    # keep rest relative to the animated parent
                    q_world = (tgt.matrix_world @ P @ rel).to_quaternion()
                W = Matrix.LocRotScale(head, q_world, Vector((1, 1, 1)))
            M = tgt.matrix_world.inverted() @ W   # armature space
            arm_m[name] = M
            if b.parent is None:
                basis = b.matrix_local.inverted() @ M
            else:
                rel = b.parent.matrix_local.inverted() @ b.matrix_local
                basis = rel.inverted() @ arm_m[b.parent.name].inverted() @ M
            loc, rot, _ = basis.decompose()
            pb.rotation_mode = 'QUATERNION'
            pb.rotation_quaternion = rot
            pb.keyframe_insert("rotation_quaternion", frame=fi)
            if b.parent is None:
                pb.location = loc
                pb.keyframe_insert("location", frame=fi)
    for fc in action.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = 'LINEAR'
    tr = tgt.animation_data.nla_tracks.new()
    tr.name = clip["name"]
    tr.strips.new(clip["name"], 0, action)
    tgt.animation_data.action = None
    # clean up source
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)
    print("CLIP", clip["name"], n, "frames")

for pb in tgt.pose.bones:
    pb.rotation_quaternion = Quaternion()
    pb.location = Vector()
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_animation_mode='NLA_TRACKS',
                          export_image_format='JPEG', export_jpeg_quality=90, export_force_sampling=True)
print("EXPORTED", OUT)
