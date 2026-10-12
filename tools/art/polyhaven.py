#!/usr/bin/env python3
"""Download CC0 PBR materials and models from Poly Haven (polyhaven.com).

    python3 tools/art/polyhaven.py textures
    python3 tools/art/polyhaven.py models

Everything Poly Haven publishes is CC0.
"""
import json
import os
import sys
import urllib.request

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "assets", "pbr")
MOUT = os.path.join(ROOT, "assets", "models", "polyhaven")

# id -> resolution. Hero ground surfaces get 2k.
TEXTURES = {
    "mud_cracked_dry_riverbed_002": "2k",  # the dead river Sookhi
    "cracked_red_ground": "2k",            # red earth
    "dry_ground_01": "1k",
    "red_laterite_soil_stones": "1k",
    "red_mud_stones": "1k",
    "large_red_bricks": "2k",              # ghat steps
    "medieval_red_brick": "1k",
    "red_brick_plaster_patch_02": "1k",
    "clay_plaster": "2k",                  # lime-washed mud houses
    "white_plaster_rough_01": "1k",
    "patterned_clay_plaster": "1k",
    "worn_plaster_wall": "1k",
    "clay_roof_tiles_02": "1k",
    "clay_floor_001": "1k",
    "excavated_soil_wall": "2k",           # the clay pits
    "burned_ground_01": "1k",              # burning ground, kiln floors
    "rock_wall_08": "1k",
    "dry_riverbed_rock": "1k",
    "rough_linen": "1k",
    "brown_mud_dry": "1k",
    "sandstone_cracks": "1k",
}

MAPS = {"Diffuse": "albedo", "nor_gl": "normal", "Rough": "rough", "AO": "ao", "Displacement": "height"}

MODELS = {
    "brass_pot_01": "1k", "brass_pot_02": "1k", "brass_vase_01": "1k", "ceramic_pot": "1k",
    "antique_ceramic_vase_01": "1k", "planter_pot_clay": "1k", "wicker_basket_01": "1k",
    "stone_fire_pit": "1k", "jug_01": "1k", "rock_09": "1k", "rock_07": "1k",
    "namaqualand_rocks_01": "1k", "vintage_oil_lamp": "1k",
}


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Dwaar-game-asset-fetch/1.0 (Godot project)"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def textures():
    for tid, res in TEXTURES.items():
        files = json.loads(get(f"https://api.polyhaven.com/files/{tid}"))
        d = os.path.join(OUT, tid)
        os.makedirs(d, exist_ok=True)
        for key, name in MAPS.items():
            if key not in files:
                continue
            r = files[key].get(res) or files[key].get("1k")
            f = r.get("jpg") or r.get("png")
            path = os.path.join(d, name + "." + ("jpg" if "jpg" in r else "png"))
            if os.path.exists(path):
                continue
            open(path, "wb").write(get(f["url"]))
        print("texture", tid, flush=True)


def models():
    for mid, res in MODELS.items():
        files = json.loads(get(f"https://api.polyhaven.com/files/{mid}"))
        g = files.get("gltf", {}).get(res) or files.get("gltf", {}).get("1k")
        if not g:
            print("no gltf for", mid)
            continue
        d = os.path.join(MOUT, mid)
        os.makedirs(d, exist_ok=True)
        main = g["gltf"]
        open(os.path.join(d, os.path.basename(main["url"])), "wb").write(get(main["url"]))
        for rel, inc in main.get("include", {}).items():
            p = os.path.join(d, rel)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            if not os.path.exists(p):
                open(p, "wb").write(get(inc["url"]))
        print("model", mid, flush=True)


if __name__ == "__main__":
    what = sys.argv[1:] or ["textures", "models"]
    if "textures" in what:
        textures()
    if "models" in what:
        models()
