#!/usr/bin/env python3
"""3D characters and creatures for Dwaar.

Pipeline per entry:  Flux concept (white bg)  ->  Rodin Gen-2 (PBR, A-pose)
->  Blender decimate + scale  ->  Uthana auto-rig  ->  retarget motion clips
->  assets/chars/<name>.glb.  Static entries (props, quadrupeds) skip rigging.

    python3 tools/art/characters.py concept [names...]
    python3 tools/art/characters.py model   [names...]
    python3 tools/art/characters.py rig     [names...]
    python3 tools/art/characters.py bake    [names...]
"""
import os
import sys
import json
import base64
import subprocess
import concurrent.futures as cf
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rep
import motions

BLENDER = "/opt/blender/blender-4.2.9-linux-x64/blender"
CACHE = os.path.join(rep.ROOT, "tools", "art", "cache", "chars")
OUT = os.path.join(rep.ROOT, "assets", "chars")

BIPED = ("full body character concept, front view, standing in a relaxed A-pose with the arms angled away from the body and the legs slightly apart, "
         "head to bare feet fully visible, isolated on a plain flat pure white background, stylized realistic 3D video game character, "
         "highly detailed clothing and skin textures, soft even studio lighting, no shadow, no text")
THING = ("single object, three-quarter view, isolated on a plain flat pure white background, stylized realistic 3D video game asset, "
         "highly detailed textures, soft even studio lighting, no shadow, no text")

HUMAN_CLIPS = ["idle", "walk", "run", "hurt", "death", "kneel", "sit", "band", "pray", "reach", "grab", "look_up", "cry"]
MONSTER_CLIPS = ["idle", "walk", "shamble", "hurt", "death", "grab", "attack1", "attack3", "throw", "crawl"]

# name: (prompt, kind, height_m, clips, tris)
CAST = {
    "tesu": ("Tesu, a thin 12-year-old Indian village boy with dark brown skin, big dark eyes and messy black hair, wearing a faded orange kurta the colour of tesu flowers and a short white dhoti, a red thread on his wrist, barefoot, nothing carried, empty hands", "biped", 1.32, list(motions.MOTIONS), 40000),
    "bindu": ("a thin 12-year-old Indian village girl with dark brown skin and one long braid, wearing a dark red cotton skirt and blouse with a mustard border, grey river clay smeared over her eyes and lips, barefoot", "biped", 1.3, ["lie", "idle", "sit", "kneel", "cry", "walk", "reach", "look_up"], 40000),
    "baba": ("a lean wiry Indian village potter in his forties with a gentle tired grieving face, thin build, bare chest, a plain white dhoti, a red thread on his wrist, forearms and hands stained with dried grey clay, short greying stubble, a smear of grey clay sealing his lips, barefoot", "biped", 1.74, HUMAN_CLIPS + ["sit_talk"], 40000),
    "kaki": ("a frail old blind Indian village woman potter, wearing a faded grey cotton sari with its end over her head, an indigo cloth band tied over her eyes, silver bangles, barefoot", "biped", 1.5, ["sit", "sit_talk", "idle", "old_walk", "pray", "band"], 40000),
    "elder": ("a stern old Indian village elder, white kurta and white dhoti, a large white turban, a long white beard, wooden-free prayer beads, barefoot", "biped", 1.72, HUMAN_CLIPS + ["old_walk"], 36000),
    "watchman": ("a burly Indian village night watchman, dark brown kurta, white dhoti, red turban, a thick stick tucked in his belt, a small clay oil lamp in one hand, sandals", "biped", 1.78, ["stand_guard", "walk", "idle", "run", "hurt", "band", "grab"], 36000),
    "villager_m": ("a lean Indian village potter man in a faded white kurta and dhoti with a saffron turban, barefoot", "biped", 1.7, ["band", "pray", "idle", "walk", "kneel", "carry"], 26000),
    "villager_f": ("an Indian village woman in a colourful faded red and mustard cotton sari with the end over her head, silver anklets, barefoot", "biped", 1.6, ["band", "pray", "idle", "walk", "kneel", "carry"], 26000),
    "thirsty": ("a horror game creature: an emaciated human corpse of the drought whose skin is cracked grey-brown like a dried riverbed, sunken hollow eyes, open dry mouth, ragged loincloth, very thin limbs", "biped", 1.65, MONSTER_CLIPS, 30000),
    "kachcha": ("a horror game creature: an unfired raw-clay humanoid, wet glossy grey-brown mud body, lumpy unfinished sculpted features covered in fingerprints and tool marks, faceless, dripping", "biped", 1.75, MONSTER_CLIPS, 30000),
    "pothead": ("a horror game creature: a thin humanoid figure of cracked grey river silt whose head is a large round red terracotta water pot with no face, ragged white cloth", "biped", 1.8, MONSTER_CLIPS, 30000),
    "stoker": ("a horror game creature: a tall faceless fire-tender of soot-black fired clay with a smooth blank head, glowing ember cracks, carrying a woven basket of burning dung cakes on its head with both raised hands", "biped", 1.9, ["carry", "walk", "throw", "hurt", "death", "idle"], 30000),
    "gaanth": ("a horror game creature: a humanoid made entirely of knotted jute rope and cords, faceless, covered in hundreds of tight knots, frayed ends", "biped", 1.9, MONSTER_CLIPS, 30000),
    "first": ("an ancient giant terracotta votive statue of a small child, crude folk-art fired red clay, round belly, cracked and chipped all over, hollow dark eye holes, white slip dots, arms at its sides", "biped", 1.3, ["idle", "crawl", "walk", "cry", "grab", "death", "attack3", "look_up"], 40000),
    "knot_keeper": ("a tall gaunt horror figure, more rope than man, wrapped in thousands of knotted counting cords hanging to the floor, long cord fingers, a knotted faceless head, a shawl woven of cords", "biped", 2.4, ["idle", "walk", "attack1", "attack3", "throw", "hurt", "death", "grab"], 40000),
    "fire_tender": ("a huge faceless kiln-stoker giant of black soot-stained fired clay with glowing orange cracks, broad shoulders, holding a very long iron fire rake in both hands", "biped", 3.2, ["idle", "walk", "sweep", "throw", "attack3", "hurt", "death"], 40000),
    "gaara": ("an enormous ancient old potter god, half-blind with one milky clouded eye, long matted grey hair and beard, skin crusted with cracked dry pale clay slip, bare chest, a loincloth, huge clay-caked hands", "biped", 2.2, ["sit", "sit_talk", "idle", "attack3", "grab", "sweep", "hurt", "death", "kneel"], 50000),
    "mother": ("a tall ghostly woman entirely covered from head to the ground by a long indigo dabu resist-printed cotton veil with white dot flower patterns, no face or skin visible, only the shape of a face pressing through the cloth", "biped", 1.9, ["idle", "walk", "reach", "grab", "attack1", "throw", "hurt", "death"], 40000),
    # static (no rig)
    "bull": ("a large terracotta votive bull figurine with a big hump, short horns and a dewlap, red fired clay with white slip painted bands and a clay garland, cracked, standing", "thing", 1.5, [], 30000),
    "swimmer": ("a long eel-like creature made of grey river silt and wet clay, a round mouth ringed with clay teeth, segmented body", "thing", 0.8, [], 24000),
    "buried_gang": ("a horrific wide low heap of a dozen clay-covered human bodies fused together into one crawling mass, many heads, many reaching arms, woven baskets and short hoes stuck in the mud, all one sculpture of wet grey clay", "thing", 3.0, [], 50000),
    "well_ring": ("a single thick ancient terracotta well ring, a short wide cylinder of red fired clay with a thick rolled rim, weathered and chipped", "thing", 0.6, [], 6000),
    "glazed_pot": ("a round glossy turquoise glazed clay pot with fine white crackle glaze and a narrow neck", "thing", 0.8, [], 8000),
    "boat": ("a small shallow boat made of red terracotta clay, smooth hand-shaped hull, empty", "thing", 0.6, [], 10000),
    "doorframe": ("a lone weathered terracotta and brick doorframe standing by itself, two thick posts and a lintel, faded handprints, no door", "thing", 3.6, [], 12000),
    "diya": ("a small traditional Indian clay oil lamp diya with a pinched spout, red earthenware", "thing", 0.06, [], 2000),
    "matka": ("a traditional round Indian red clay water pot matka with a short neck and white slip bands", "thing", 0.55, [], 4000),
    "surahi": ("a traditional Indian long-necked clay water pitcher surahi, red earthenware with carved lines", "thing", 0.6, [], 4000),
    "wheel": ("a large traditional Indian potter's wheel, a heavy flat stone disc on the ground with a lump of wet clay in the center", "thing", 0.35, [], 8000),
    "kiln": ("a traditional Indian potter's dome kiln of clay and brick with an arched firing mouth, soot-blackened, cracked", "thing", 3.0, [], 20000),
    "terracotta_hand": ("a terracotta votive offering in the shape of a human hand, crude red fired clay, cracked", "thing", 0.5, [], 6000),
    "terracotta_child": ("a small terracotta votive figurine of a standing child, crude folk-art red fired clay, round eyes", "thing", 1.0, [], 12000),
    "terracotta_house": ("a small terracotta votive model of a village house, red fired clay", "thing", 0.6, [], 8000),
}


def concept(name):
    prompt, kind, h, clips, tris = CAST[name]
    out = f"assets/art/chars/src/{name}_concept.png"
    rep.image(out, prompt + ", " + (BIPED if kind == "biped" else THING), "2:3" if kind == "biped" else "1:1", style=False, seed=100 + len(name))
    return out


def model(name):
    prompt, kind, h, clips, tris = CAST[name]
    raw = os.path.join(CACHE, name + "_rodin.glb")
    if not os.path.exists(raw):
        src = os.path.join(rep.ROOT, f"assets/art/chars/src/{name}_concept.png")
        b64 = "data:image/png;base64," + base64.b64encode(open(src, "rb").read()).decode()
        out = rep.run("hyper3d/rodin", {"images": [b64], "prompt": prompt, "tapose": kind == "biped", "quality": "high",
                                        "material": "PBR", "mesh_mode": "Raw", "geometry_file_format": "glb", "seed": 7}, timeout=1800)
        rep.download(out if isinstance(out, str) else rep._first(out), raw)
    lo = os.path.join(CACHE, name + "_lo.glb")
    if not os.path.exists(lo):
        subprocess.run([BLENDER, "-b", "-P", os.path.join(rep.ROOT, "tools/blender/decimate.py"), "--", raw, lo, str(tris), str(h)],
                       check=True, capture_output=True)
    if kind != "biped":
        os.makedirs(OUT, exist_ok=True)
        dst = os.path.join(OUT, name + ".glb")
        if not os.path.exists(dst):
            import shutil
            shutil.copy(lo, dst)
    return lo


def rig(name):
    prompt, kind, h, clips, tris = CAST[name]
    if kind != "biped":
        return None
    rigged = os.path.join(CACHE, name + "_rigged.glb")
    if not os.path.exists(rigged):
        lo = os.path.join(CACHE, name + "_lo.glb")
        b64 = "data:application/octet-stream;base64," + base64.b64encode(open(lo, "rb").read()).decode()
        out = rep.run("uthana/create-character-v1", {"character_file": b64, "auto_rig": True, "front_facing": True}, timeout=1700)
        rep.download(out if isinstance(out, str) else rep._first(out), rigged)
    return rigged


def bake(name):
    prompt, kind, h, clips, tris = CAST[name]
    if kind != "biped":
        return None
    rigged = os.path.join(CACHE, name + "_rigged.glb")
    cj = os.path.join(CACHE, name + "_clips.json")
    json.dump(motions.clips(clips), open(cj, "w"))
    os.makedirs(OUT, exist_ok=True)
    dst = os.path.join(OUT, name + ".glb")
    r = subprocess.run([BLENDER, "-b", "-P", os.path.join(rep.ROOT, "tools/blender/retarget.py"), "--", rigged, dst, cj], capture_output=True, text=True)
    if "EXPORTED" not in r.stdout:
        raise RuntimeError(r.stdout[-2000:] + r.stderr[-2000:])
    return dst


def stage(fn, names, workers):
    with cf.ThreadPoolExecutor(max_workers=workers) as ex:
        futs = {ex.submit(fn, n): n for n in names}
        for f in cf.as_completed(futs):
            n = futs[f]
            try:
                f.result()
                print("ok", fn.__name__, n, flush=True)
            except Exception as e:
                print("FAIL", fn.__name__, n, str(e)[:500], flush=True)


if __name__ == "__main__":
    os.makedirs(CACHE, exist_ok=True)
    step = sys.argv[1]
    names = sys.argv[2:] or list(CAST)
    if step == "concept":
        stage(concept, names, 8)
    elif step == "model":
        stage(model, names, 6)
    elif step == "rig":
        stage(rig, names, 6)
    elif step == "bake":
        stage(bake, names, 3)
    elif step == "all":
        stage(concept, names, 8)
        stage(model, names, 6)
        stage(rig, names, 6)
        stage(bake, names, 3)
