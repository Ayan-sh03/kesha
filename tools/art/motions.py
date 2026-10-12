#!/usr/bin/env python3
"""Text-to-motion library (Uthana) for every character in Dwaar.

    python3 tools/art/motions.py            # fetch all clips into tools/art/cache/motions
"""
import os
import sys
import json
import concurrent.futures as cf
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rep

DIR = os.path.join(rep.ROOT, "tools", "art", "cache", "motions")

# name: (prompt, seconds, loop, extra retarget options)
MOTIONS = {
    "idle": ("a nervous child stands still breathing, shifting weight slightly and glancing around", 6, True, {"min_len": 1.6, "max_len": 4.5}),
    "walk": ("a child walks forward at a normal pace", 4, True, {"min_len": 0.8, "max_len": 1.6}),
    "run": ("a child sprints forward quickly", 4, True, {"min_len": 0.45, "max_len": 1.1}),
    "sneak": ("a person sneaks forward slowly, crouched low, tiptoeing quietly", 5, True, {"min_len": 1.0, "max_len": 2.5}),
    "jump": ("a person crouches and jumps straight up high, arms swinging up", 2.0, False, {"trim_peak": "mixamorig:Hips", "axis": "z", "pre": 0.25, "post": 0.35}),
    "fall": ("a person falls down through the air with arms flailing", 3, True, {"min_len": 0.6, "max_len": 1.6, "inplace_z": True}),
    "land": ("a person lands from a high jump into a crouch and stands back up", 1.5, False, {"start_s": 0.2}),
    "climb": ("a person climbs up a vertical ladder hand over hand", 4, True, {"min_len": 0.8, "max_len": 2.0, "inplace_z": True}),
    "attack1": ("a person swings a short stick forcefully from right to left with the right hand", 1.4, False, {"trim_peak": "mixamorig:RightHand", "pre": 0.28, "post": 0.32}),
    "attack2": ("a person does a quick backhand swing with a stick in the right hand", 1.4, False, {"trim_peak": "mixamorig:RightHand", "pre": 0.28, "post": 0.32}),
    "attack3": ("a person raises a stick high overhead with both hands and smashes it down hard", 1.8, False, {"trim_peak": "mixamorig:RightHand", "pre": 0.45, "post": 0.4}),
    "aim": ("a person aims a slingshot, holding it out with the left hand and pulling back the band to the cheek with the right hand, steady", 3, True, {"min_len": 1.0, "max_len": 2.5}),
    "shoot": ("a person releases a slingshot shot, the right arm snapping forward", 1.2, False, {"trim_peak": "mixamorig:RightHand", "pre": 0.1, "post": 0.35}),
    "block": ("a person braces and raises both forearms in front of the face to block a blow", 2, False, {"trim_peak": "mixamorig:RightHand", "pre": 0.25, "post": 0.25}),
    "roll": ("a person does a quick forward roll on the ground and stands up", 1.6, False, {"inplace": True}),
    "hurt": ("a person is hit hard in the chest and staggers backward", 1.2, False, {"trim_peak": "mixamorig:Spine2", "pre": 0.1, "post": 0.5}),
    "death": ("a person collapses and falls dead on the ground", 3, False, {}),
    "band": ("a person stands with fingers pressed into both ears, eyes shut, head bowed, holding breath, very still", 5, True, {"min_len": 1.5, "max_len": 4.0}),
    "pray": ("a person stands still with palms pressed together in prayer, head bowed", 5, True, {"min_len": 1.5, "max_len": 4.0}),
    "kneel": ("a person kneels down on both knees and bows the head", 3, False, {}),
    "sit": ("a person sits cross-legged on the ground, breathing quietly", 5, True, {"min_len": 1.5, "max_len": 4.0}),
    "sit_talk": ("an old woman sits cross-legged and gestures with her hands while talking", 6, True, {"min_len": 2.0, "max_len": 5.0}),
    "reach": ("a person runs a few steps, stops and reaches out desperately with one arm", 3, False, {}),
    "crawl": ("a person crawls forward on hands and knees", 4, True, {"min_len": 0.8, "max_len": 2.2}),
    "grab": ("a person lunges forward and grabs with both arms", 1.5, False, {"trim_peak": "mixamorig:RightHand", "pre": 0.4, "post": 0.45}),
    "cry": ("a person kneels and sobs with hands over the face", 4, True, {"min_len": 1.5, "max_len": 3.5}),
    "carry": ("a person walks forward slowly carrying a heavy basket on the head with both hands", 4, True, {"min_len": 0.9, "max_len": 2.0}),
    "shamble": ("a stiff zombie shambles forward slowly, dragging the feet, arms hanging", 5, True, {"min_len": 1.0, "max_len": 3.0}),
    "old_walk": ("an old man walks slowly with a stooped back", 4, True, {"min_len": 1.0, "max_len": 2.2}),
    "throw": ("a person throws an object overhand", 1.6, False, {"trim_peak": "mixamorig:RightHand", "pre": 0.5, "post": 0.4}),
    "sweep": ("a large man swings a long heavy rake in a wide sweeping arc", 2.5, False, {"trim_peak": "mixamorig:RightHand", "pre": 0.7, "post": 0.6}),
    "lie": ("a person lies on their back on the ground, motionless", 3, True, {"min_len": 1.0, "max_len": 2.5}),
    "look_up": ("a person looks up anxiously at something huge above", 3, False, {}),
    "stand_guard": ("a guard stands still holding a lamp, looking left and right", 5, True, {"min_len": 1.5, "max_len": 4.0}),
}


def fetch(name):
    path = os.path.join(DIR, name + ".glb")
    if os.path.exists(path):
        return name, None
    prompt, secs, loop, _ = MOTIONS[name]
    try:
        out = rep.run("uthana/text-to-motion-diffusion-v2", {"prompt": prompt, "character": "Y Bot", "output_ext": "GLB", "fps": 30,
                                                              "motion_length": secs, "no_mesh": False, "seed": 7}, timeout=900)
        rep.download(out if isinstance(out, str) else rep._first(out), path)
        return name, None
    except Exception as e:
        return name, str(e)


def clips(names=None, overrides=None):
    """Retarget clip list for tools/blender/retarget.py."""
    out = []
    for n in (names or MOTIONS):
        prompt, secs, loop, opt = MOTIONS[n]
        c = {"name": n, "file": os.path.join(DIR, n + ".glb"), "loop": loop}
        c.update(opt)
        if overrides and n in overrides:
            c.update(overrides[n])
        out.append(c)
    return out


if __name__ == "__main__":
    os.makedirs(DIR, exist_ok=True)
    names = sys.argv[1:] or list(MOTIONS)
    with cf.ThreadPoolExecutor(max_workers=6) as ex:
        for n, err in ex.map(fetch, names):
            print(("FAIL " + n + ": " + err) if err else ("ok " + n), flush=True)
