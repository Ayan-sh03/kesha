#!/usr/bin/env python3
"""Replicate helper for Dwaar's art pipeline.

The API token is read from $REPLICATE_API_TOKEN or ~/.config/dwaar/replicate_token
and is never written into the repository. Every generated asset is cached on
disk and its prompt is recorded in tools/art/manifest.json, so the art can be
regenerated or audited.
"""
import io
import json
import os
import sys
import time
import urllib.request
import urllib.error

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
CACHE = os.path.join(ROOT, "tools", "art", "cache")
MANIFEST = os.path.join(ROOT, "tools", "art", "manifest.json")
API = "https://api.replicate.com/v1"

VERSIONS = {
    "birefnet": "men1scus/birefnet:f74986db0355b58403ed20963af156525e2891ea3c2d499bfbfb2a28cd87c5d7",
    "depth": "chenxwh/depth-anything-v2:b239ea33cff32bb7abb5db39ffe9a09c14cbc2894331d1ef66fe096eed88ebd4",
    "esrgan": "nightmareai/real-esrgan:b3ef194191d13140337468c916c2c5b96dd0cb06dffc032a022a31807f6a5ea8",
}

# Shared art direction so every picture belongs to the same game.
STYLE = ("hand-painted 2D video game art, painterly brushwork, rich detail, dramatic chiaroscuro, "
         "muted indigo night and red-earth terracotta palette, rural India, potters' village, "
         "dark atmospheric side-scroller in the spirit of Inside, Hollow Knight and Ori, cinematic lighting, no text, no watermark")


def token():
    t = os.environ.get("REPLICATE_API_TOKEN")
    if not t:
        p = os.path.expanduser("~/.config/dwaar/replicate_token")
        t = open(p).read().strip()
    return t


def _req(method, url, body=None, headers=None):
    h = {"Authorization": "Bearer " + token(), "Content-Type": "application/json"}
    if headers:
        h.update(headers)
    data = json.dumps(body).encode() if body is not None else None
    for attempt in range(41):
        try:
            r = urllib.request.Request(url, data=data, headers=h, method=method)
            with urllib.request.urlopen(r, timeout=180) as resp:
                return json.loads(resp.read())
        except urllib.error.HTTPError as e:
            msg = e.read().decode(errors="ignore")
            if e.code == 429 and attempt < 40:
                try:
                    wait = float(json.loads(msg).get("retry_after", 10))
                except Exception:
                    wait = 10.0
                time.sleep(wait + 1 + (attempt % 5))
                continue
            if e.code in (500, 502, 503, 504) and attempt < 5:
                time.sleep(2 ** attempt + 1)
                continue
            raise RuntimeError(f"{e.code} {msg[:400]}")
        except (urllib.error.URLError, TimeoutError):
            if attempt < 5:
                time.sleep(2 ** attempt + 1)
                continue
            raise


def run(model, inputs, timeout=900):
    """Run a model. `model` is 'owner/name' (official) or a key of VERSIONS / 'owner/name:version'."""
    model = VERSIONS.get(model, model)
    if ":" in model:
        ver = model.split(":", 1)[1]
        pred = _req("POST", f"{API}/predictions", {"version": ver, "input": inputs}, {"Prefer": "wait=60"})
    else:
        pred = _req("POST", f"{API}/models/{model}/predictions", {"input": inputs}, {"Prefer": "wait=60"})
    t0 = time.time()
    while pred.get("status") not in ("succeeded", "failed", "canceled"):
        if time.time() - t0 > timeout:
            raise RuntimeError("timeout")
        time.sleep(2)
        pred = _req("GET", pred["urls"]["get"])
    if pred["status"] != "succeeded":
        raise RuntimeError(f"{model}: {pred.get('error')}")
    return pred["output"]


def download(url, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    for attempt in range(5):
        try:
            with urllib.request.urlopen(url, timeout=180) as r:
                data = r.read()
            with open(path, "wb") as f:
                f.write(data)
            return path
        except Exception:
            if attempt == 4:
                raise
            time.sleep(2 ** attempt)


def _first(out):
    if isinstance(out, list):
        return out[0]
    if isinstance(out, dict):
        for v in out.values():
            if isinstance(v, str) and v.startswith("http"):
                return v
    return out


def _manifest_set(key, value):
    m = {}
    if os.path.exists(MANIFEST):
        m = json.load(open(MANIFEST))
    m[key] = value
    json.dump(m, open(MANIFEST, "w"), indent=1, sort_keys=True)


def crop_bars(im, thresh=14):
    """Remove letterbox bars some models paint into wide images."""
    import numpy as np
    a = np.asarray(im.convert("L")).astype(float)
    rows = a.mean(1)
    top = 0
    while top < len(rows) // 3 and rows[top] < thresh:
        top += 1
    bot = len(rows)
    while bot > len(rows) * 2 // 3 and rows[bot - 1] < thresh:
        bot -= 1
    return im.crop((0, top, im.width, bot))


def image(out_path, prompt, aspect="16:9", ultra=False, seed=None, style=True, raw=False, model=None, extra=None, force=False):
    """Generate an image to out_path (relative to repo root) if it doesn't exist."""
    full = os.path.join(ROOT, out_path)
    if os.path.exists(full) and not force:
        return full
    p = prompt + (", " + STYLE if style else "")
    m = model or ("black-forest-labs/flux-1.1-pro-ultra" if ultra else "black-forest-labs/flux-1.1-pro")
    inp = {"prompt": p, "aspect_ratio": aspect, "output_format": "png", "safety_tolerance": 5}
    if ultra:
        inp["raw"] = raw
    if seed is not None:
        inp["seed"] = seed
    if extra:
        inp.update(extra)
    url = _first(run(m, inp))
    tmp = os.path.join(CACHE, os.path.basename(out_path) + ".raw.png")
    download(url, tmp)
    from PIL import Image
    im = Image.open(tmp).convert("RGB")
    if ultra:
        im = crop_bars(im)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    im.save(full)
    _manifest_set(out_path, {"model": m, "prompt": p, "aspect": aspect, "seed": seed})
    print("generated", out_path, im.size, flush=True)
    return full


def edit(out_path, src_path, prompt, aspect="match_input_image", force=False):
    """Flux Kontext: edit an existing image (keeps characters consistent)."""
    full = os.path.join(ROOT, out_path)
    if os.path.exists(full) and not force:
        return full
    import base64
    src = os.path.join(ROOT, src_path)
    b64 = "data:image/png;base64," + base64.b64encode(open(src, "rb").read()).decode()
    url = _first(run("black-forest-labs/flux-kontext-pro", {"prompt": prompt, "input_image": b64, "aspect_ratio": aspect, "output_format": "png", "safety_tolerance": 2}))
    tmp = os.path.join(CACHE, os.path.basename(out_path) + ".raw.png")
    download(url, tmp)
    from PIL import Image
    Image.open(tmp).convert("RGB").save(full)
    _manifest_set(out_path, {"model": "flux-kontext-pro", "prompt": prompt, "from": src_path})
    print("edited", out_path, flush=True)
    return full


def cutout(src_path, out_path, force=False):
    """Background removal (BiRefNet) -> RGBA PNG."""
    full = os.path.join(ROOT, out_path)
    if os.path.exists(full) and not force:
        return full
    import base64
    src = os.path.join(ROOT, src_path)
    b64 = "data:image/png;base64," + base64.b64encode(open(src, "rb").read()).decode()
    url = _first(run("birefnet", {"image": b64}))
    tmp = os.path.join(CACHE, os.path.basename(out_path) + ".mask.png")
    download(url, tmp)
    from PIL import Image
    m = Image.open(tmp)
    rgb = Image.open(src).convert("RGB")
    if m.mode == "RGBA":
        alpha = m.split()[3]
    else:
        alpha = m.convert("L")
    alpha = alpha.resize(rgb.size)
    rgba = rgb.copy()
    rgba.putalpha(alpha)
    bbox = alpha.point(lambda v: 255 if v > 8 else 0).getbbox()
    if bbox:
        rgba = rgba.crop(bbox)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    rgba.save(full)
    print("cutout", out_path, rgba.size, flush=True)
    return full


def depth(src_path, out_path, force=False):
    full = os.path.join(ROOT, out_path)
    if os.path.exists(full) and not force:
        return full
    import base64
    src = os.path.join(ROOT, src_path)
    from PIL import Image
    im = Image.open(src)
    buf = io.BytesIO()
    im.convert("RGB").save(buf, "PNG")
    b64 = "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()
    out = run("depth", {"image": b64})
    url = out.get("grey_depth") if isinstance(out, dict) else _first(out)
    download(url, full)
    print("depth", out_path, flush=True)
    return full


def upscale(src_path, out_path, scale=2, force=False):
    full = os.path.join(ROOT, out_path)
    if os.path.exists(full) and not force:
        return full
    import base64
    src = os.path.join(ROOT, src_path)
    b64 = "data:image/png;base64," + base64.b64encode(open(src, "rb").read()).decode()
    url = _first(run("esrgan", {"image": b64, "scale": scale}))
    download(url, full)
    print("upscaled", out_path, flush=True)
    return full


def model3d(out_path, image_path, model="tencent/hunyuan3d-2", extra=None, force=False):
    """Image-to-3D (textured GLB)."""
    full = os.path.join(ROOT, out_path)
    if os.path.exists(full) and not force:
        return full
    import base64
    src = os.path.join(ROOT, image_path)
    b64 = "data:image/png;base64," + base64.b64encode(open(src, "rb").read()).decode()
    inp = {"image": b64}
    if extra:
        inp.update(extra)
    out = run(model, inp, timeout=1800)
    url = None
    if isinstance(out, dict):
        for k in ("mesh", "model_file", "glb", "output"):
            if isinstance(out.get(k), str):
                url = out[k]
                break
        if url is None:
            url = _first(out)
    else:
        url = _first(out)
    download(url, full)
    _manifest_set(out_path, {"model": model, "from": image_path})
    print("3d", out_path, flush=True)
    return full


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "image":
        image(sys.argv[2], sys.argv[3], *(sys.argv[4:5] or []))
    elif cmd == "cutout":
        cutout(sys.argv[2], sys.argv[3])
