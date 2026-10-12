#!/usr/bin/env python3
"""Procedural texture generator for Dwaar.

Every texture in the game is generated here from noise, so the art is
original and free of third-party licences. Run:

    python3 tools/gen_textures.py

Outputs tileable albedo / normal / roughness PNGs into assets/textures/.
"""
import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
os.makedirs(OUT, exist_ok=True)
RNG = np.random.default_rng(1729)
N = 1024


# ---------------------------------------------------------------- noise
def fnoise(n, beta=2.0, seed=None, aniso=(1.0, 1.0)):
    """Tileable 1/f^beta noise via FFT, normalised 0..1."""
    rng = np.random.default_rng(seed) if seed is not None else RNG
    w = rng.normal(size=(n, n))
    f = np.fft.fft2(w)
    ky = np.fft.fftfreq(n)[:, None] * aniso[1]
    kx = np.fft.fftfreq(n)[None, :] * aniso[0]
    k = np.sqrt(kx * kx + ky * ky)
    k[0, 0] = 1.0
    f = f / (k ** (beta / 2.0))
    f[0, 0] = 0
    r = np.real(np.fft.ifft2(f))
    r -= r.min()
    r /= r.max() + 1e-9
    return r


def band(n, lo, hi, seed=None):
    rng = np.random.default_rng(seed) if seed is not None else RNG
    w = rng.normal(size=(n, n))
    f = np.fft.fft2(w)
    ky = np.fft.fftfreq(n)[:, None] * n
    kx = np.fft.fftfreq(n)[None, :] * n
    k = np.sqrt(kx * kx + ky * ky)
    mask = ((k >= lo) & (k <= hi)).astype(float)
    r = np.real(np.fft.ifft2(f * mask))
    r -= r.min()
    r /= r.max() + 1e-9
    return r


def voronoi(n, cells, seed=0, jitter=1.0):
    """Tileable voronoi. Returns (F1, F2, cell_id)."""
    rng = np.random.default_rng(seed)
    pts = rng.random((cells, 2))
    yy, xx = np.mgrid[0:n, 0:n] / n
    f1 = np.full((n, n), 9.0)
    f2 = np.full((n, n), 9.0)
    cid = np.zeros((n, n), dtype=np.int32)
    for i, (px, py) in enumerate(pts):
        dx = np.abs(xx - px)
        dx = np.minimum(dx, 1 - dx)
        dy = np.abs(yy - py)
        dy = np.minimum(dy, 1 - dy)
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < f1
        f2 = np.where(closer, f1, np.minimum(f2, d))
        cid = np.where(closer, i, cid)
        f1 = np.where(closer, d, f1)
    return f1, f2, cid


def warp(img, amt, seed=None):
    n = img.shape[0]
    wx = (fnoise(n, 3.0, seed) - 0.5) * amt * n
    wy = (fnoise(n, 3.0, None if seed is None else seed + 1) - 0.5) * amt * n
    yy, xx = np.mgrid[0:n, 0:n]
    sx = (xx + wx).astype(int) % n
    sy = (yy + wy).astype(int) % n
    return img[sy, sx]


def normal_from_height(h, strength=4.0):
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    nz = np.ones_like(h)
    l = np.sqrt(gx * gx + gy * gy + nz * nz)
    nx, ny, nz = -gx / l, gy / l, nz / l  # OpenGL-style (Godot uses +Y up)
    rgb = np.stack([nx * 0.5 + 0.5, ny * 0.5 + 0.5, nz * 0.5 + 0.5], -1)
    return rgb


def lerp(a, b, t):
    return a + (b - a) * t


def col(hexs):
    hexs = hexs.lstrip("#")
    return np.array([int(hexs[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def mix_cols(t, c0, c1):
    t = np.clip(t, 0, 1)[..., None]
    return c0[None, None, :] * (1 - t) + c1[None, None, :] * t


def save_rgb(name, rgb):
    a = (np.clip(rgb, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(a, "RGB").save(os.path.join(OUT, name), optimize=True)
    print("wrote", name)


def save_l(name, g):
    a = (np.clip(g, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(a, "L").save(os.path.join(OUT, name), optimize=True)
    print("wrote", name)


def save_set(base, albedo, height, rough, nstr=4.0):
    save_rgb(base + "_albedo.png", albedo)
    save_rgb(base + "_normal.png", normal_from_height(height, nstr))
    save_l(base + "_rough.png", rough)


# ---------------------------------------------------------------- sets
def terracotta():
    n = N
    big = fnoise(n, 3.2, 11)
    mid = fnoise(n, 2.2, 12)
    fine = band(n, 120, 400, 13)
    smoke = np.clip((fnoise(n, 3.6, 14) - 0.55) * 3.0, 0, 1)
    base = mix_cols(big * 0.7 + mid * 0.3, col("#8f3b22"), col("#c9714a"))
    base = base * (0.9 + 0.2 * fine[..., None])
    base = lerp(base, col("#2a1a14")[None, None, :], smoke[..., None] * 0.55)
    pits = (band(n, 200, 512, 15) > 0.82).astype(float)
    base *= (1 - pits[..., None] * 0.25)
    h = mid * 0.4 + fine * 0.3 - pits * 0.3
    rough = 0.72 + 0.2 * fine - smoke * 0.1
    save_set("terracotta", base, h, rough, 3.0)


def silt():
    n = N
    f1, f2, cid = voronoi(n, 70, 21)
    edge = f2 - f1
    crack = np.clip(1.0 - edge / 0.012, 0, 1) ** 1.5
    crack = warp(crack, 0.01, 22)
    cell_tone = (cid * 0.6180339) % 1.0
    curl = np.clip(1.0 - edge / 0.05, 0, 1)  # edges curl upward
    big = fnoise(n, 3.0, 23)
    fine = band(n, 150, 500, 24)
    base = mix_cols(big * 0.6 + cell_tone * 0.25 + fine * 0.15, col("#6d6255"), col("#a89884"))
    base = lerp(base, col("#2b241e")[None, None, :], crack[..., None] * 0.95)
    base = lerp(base, col("#c4b5a0")[None, None, :], (curl * (1 - crack))[..., None] * 0.25)
    h = 0.6 + curl * 0.25 - crack * 0.85 + fine * 0.05
    rough = 0.9 - crack * 0.1
    save_set("silt", base, h, rough, 5.0)


def limewash():
    n = N
    big = fnoise(n, 3.4, 31)
    mid = fnoise(n, 2.4, 32)
    flake = np.clip((fnoise(n, 2.8, 33) - 0.62) * 6, 0, 1)
    drip = fnoise(n, 2.0, 34, aniso=(8.0, 0.4))
    base = mix_cols(big * 0.5 + mid * 0.5, col("#bfc4c6"), col("#ecebe3"))
    base = lerp(base, col("#9aa7b5")[None, None, :], (drip > 0.7)[..., None] * 0.18)
    base = lerp(base, col("#a8573a")[None, None, :], flake[..., None] * 0.85)
    h = mid * 0.2 + (1 - flake) * 0.3
    rough = 0.88 + 0.1 * mid
    save_set("limewash", base, h, rough, 3.0)


def brick():
    n = N
    rows, bw = 24, 1.0 / 5.0
    yy, xx = np.mgrid[0:n, 0:n] / n
    row = np.floor(yy * rows)
    off = (row % 2) * bw * 0.5
    bx = ((xx + off) % bw) / bw
    by = (yy * rows) % 1.0
    mortar = np.clip(1 - np.minimum.reduce([bx / 0.03, (1 - bx) / 0.03, by / 0.09, (1 - by) / 0.09]), 0, 1)
    bid = (np.floor((xx + off) / bw) * 7.13 + row * 3.71) % 1.0
    wear = fnoise(n, 2.6, 41)
    chip = np.clip((band(n, 60, 200, 42) - 0.7) * 5, 0, 1)
    tone = bid * 0.6 + wear * 0.4
    base = mix_cols(tone, col("#6e2e1d"), col("#b0603e"))
    base = lerp(base, col("#8b8174")[None, None, :], mortar[..., None])
    base *= (0.85 + 0.25 * band(n, 200, 500, 43))[..., None]
    silt_stain = np.clip((fnoise(n, 3.0, 44) - 0.45) * 2.5, 0, 1) * np.clip(1 - yy * 1.2 + 0.3, 0, 1)
    base = lerp(base, col("#8a7d6a")[None, None, :], silt_stain[..., None] * 0.6)
    h = (1 - mortar) * 0.7 + wear * 0.2 - chip * 0.3
    rough = 0.8 + mortar * 0.15
    save_set("brick", base, h, rough, 5.0)


def soot():
    n = N
    big = fnoise(n, 3.0, 51)
    fine = band(n, 100, 400, 52)
    ash = np.clip((fnoise(n, 2.4, 53) - 0.6) * 4, 0, 1)
    base = mix_cols(big * 0.6 + fine * 0.4, col("#0d0b0a"), col("#2e2722"))
    base = lerp(base, col("#7a726a")[None, None, :], ash[..., None] * 0.6)
    h = big * 0.3 + fine * 0.3 + ash * 0.2
    rough = 0.95 - ash * 0.1
    save_set("soot", base, h, rough, 3.0)
    ember = np.clip((band(n, 80, 300, 54) - 0.86) * 12, 0, 1) * np.clip((big - 0.4) * 3, 0, 1)
    emb = np.stack([ember, ember * 0.35, ember * 0.08], -1)
    save_rgb("soot_emission.png", emb)


def wetclay():
    n = N
    big = fnoise(n, 3.0, 61)
    swirl = warp(fnoise(n, 2.2, 62), 0.05, 63)
    finger = (np.sin((swirl * 40.0)) * 0.5 + 0.5)
    base = mix_cols(big * 0.6 + swirl * 0.4, col("#3d2418"), col("#6b3f28"))
    h = swirl * 0.5 + finger * 0.08
    rough = 0.25 + 0.25 * big
    save_set("wetclay", base, h, rough, 4.0)


def rope():
    n = 512
    yy, xx = np.mgrid[0:n, 0:n] / n
    strands = 6
    s = np.sin((xx * strands + yy * 2.0) * 2 * math.pi)
    fibre = band(n, 80, 250, 71)
    h = (s * 0.5 + 0.5) ** 0.6 * 0.8 + fibre * 0.2
    base = mix_cols(h * 0.7 + fnoise(n, 3, 72) * 0.3, col("#5a4630"), col("#b39a6e"))
    rough = 0.9 + 0 * h
    save_rgb("rope_albedo.png", base)
    save_rgb("rope_normal.png", normal_from_height(h, 6.0))
    save_l("rope_rough.png", rough)


def indigo():
    """Indigo cloth with dabu (mud-resist) print: dots and small booti flowers."""
    n = N
    yy, xx = np.mgrid[0:n, 0:n]
    weave = (np.sin(xx * math.pi / 2.0) * np.sin(yy * math.pi / 2.0)) * 0.5 + 0.5
    vat = fnoise(n, 3.3, 81)
    base = mix_cols(vat, col("#0b1638"), col("#22356e"))
    img = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(img)
    step = n // 8
    rng = np.random.default_rng(82)
    for gy in range(8):
        for gx in range(8):
            cx = gx * step + (step // 2 if gy % 2 else 0)
            cy = gy * step + step // 2
            for ox in (-n, 0, n):
                for oy in (-n, 0, n):
                    x, y = cx + ox, cy + oy
                    r = step * 0.16
                    for k in range(6):  # petals
                        a = k / 6 * 2 * math.pi
                        px, py = x + math.cos(a) * r * 1.6, y + math.sin(a) * r * 1.6
                        d.ellipse([px - r * 0.7, py - r * 0.7, px + r * 0.7, py + r * 0.7], fill=255)
                    d.ellipse([x - r * 0.5, y - r * 0.5, x + r * 0.5, y + r * 0.5], fill=0)
                    for k in range(12):  # dot ring
                        a = k / 12 * 2 * math.pi
                        px, py = x + math.cos(a) * step * 0.42, y + math.sin(a) * step * 0.42
                        rr = step * 0.035 * (0.7 + rng.random() * 0.6)
                        d.ellipse([px - rr, py - rr, px + rr, py + rr], fill=255)
    pat = np.asarray(img.filter(ImageFilter.GaussianBlur(1.6))).astype(float) / 255.0
    bleed = warp(pat, 0.004, 83)
    resist = np.clip(bleed * (0.7 + 0.5 * fnoise(n, 2.0, 84)), 0, 1)
    base = lerp(base, col("#c9cfdc")[None, None, :], resist[..., None] * 0.85)
    base *= (0.85 + 0.2 * weave)[..., None]
    h = weave * 0.5 + vat * 0.2
    save_set("indigo", base, h, 0.92 + 0 * h, 2.5)


def ochre_cloth():
    n = 512
    yy, xx = np.mgrid[0:n, 0:n]
    weave = (np.sin(xx * math.pi / 2.0) * np.sin(yy * math.pi / 2.0)) * 0.5 + 0.5
    v = fnoise(n, 3.0, 91)
    base = mix_cols(v, col("#a8652a"), col("#d99a4a")) * (0.88 + 0.16 * weave)[..., None]
    save_rgb("ochre_albedo.png", base)
    save_rgb("ochre_normal.png", normal_from_height(weave * 0.5, 2.0))


def skin():
    n = 512
    v = fnoise(n, 3.2, 95)
    base = mix_cols(v, col("#6a3b26"), col("#8b5236"))
    save_rgb("skin_albedo.png", base)


def glaze():
    """Glazed pot with crackle: used for Glazed Doubles and the Mother's mirrors."""
    n = 512
    f1, f2, cid = voronoi(n, 160, 101)
    crack = np.clip(1 - (f2 - f1) / 0.004, 0, 1)
    v = fnoise(n, 3.0, 102)
    base = mix_cols(v, col("#123a4a"), col("#2f7d86"))
    base = lerp(base, col("#d7e6da")[None, None, :], crack[..., None] * 0.6)
    save_rgb("glaze_albedo.png", base)
    save_rgb("glaze_normal.png", normal_from_height(1 - crack * 0.3, 2.0))


# ---------------------------------------------------------------- chalk
def chalk_stroke(d, pts, w, rng):
    """Draw a wobbly child-like chalk stroke through pts."""
    for i in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        steps = max(2, int(math.hypot(x1 - x0, y1 - y0) / 2))
        for s in range(steps):
            t = s / steps
            x = x0 + (x1 - x0) * t + rng.normal() * 1.2
            y = y0 + (y1 - y0) * t + rng.normal() * 1.2
            for _ in range(3):
                jx, jy = rng.normal() * w * 0.35, rng.normal() * w * 0.35
                r = w * (0.35 + rng.random() * 0.3)
                a = int(150 + rng.random() * 105)
                d.ellipse([x + jx - r, y + jy - r, x + jx + r, y + jy + r], fill=a)


def wobble_line(p0, p1, n=8, amp=4, rng=None):
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append((p0[0] + (p1[0] - p0[0]) * t + rng.normal() * amp,
                    p0[1] + (p1[1] - p0[1]) * t + rng.normal() * amp))
    return pts


def wobble_circle(cx, cy, r, rng, turns=1.08, n=40):
    pts = []
    for i in range(n + 1):
        a = i / n * 2 * math.pi * turns
        rr = r * (1 + rng.normal() * 0.04)
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    return pts


def save_chalk(name, img):
    a = np.asarray(img).astype(float) / 255.0
    grain = band(img.size[0], 60, 256, hash(name) % 1000)
    a = np.clip(a * (0.55 + 0.6 * grain), 0, 1)
    rgba = np.zeros((img.size[1], img.size[0], 4))
    rgba[..., 0] = 0.95
    rgba[..., 1] = 0.94
    rgba[..., 2] = 0.88
    rgba[..., 3] = a
    Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, name), optimize=True)
    print("wrote", name)


def chalk_marks():
    S = 256
    rng = np.random.default_rng(111)
    # arrow
    img = Image.new("L", (S, S), 0); d = ImageDraw.Draw(img)
    chalk_stroke(d, wobble_line((30, 140), (210, 120), 10, 3, rng), 9, rng)
    chalk_stroke(d, wobble_line((210, 120), (160, 70), 5, 3, rng), 9, rng)
    chalk_stroke(d, wobble_line((210, 120), (170, 180), 5, 3, rng), 9, rng)
    save_chalk("chalk_arrow.png", img)
    # circle
    img = Image.new("L", (S, S), 0); d = ImageDraw.Draw(img)
    chalk_stroke(d, wobble_circle(128, 128, 95, rng), 9, rng)
    save_chalk("chalk_circle.png", img)
    # cross
    img = Image.new("L", (S, S), 0); d = ImageDraw.Draw(img)
    chalk_stroke(d, wobble_line((50, 50), (205, 210), 8, 4, rng), 11, rng)
    chalk_stroke(d, wobble_line((205, 45), (55, 205), 8, 4, rng), 11, rng)
    save_chalk("chalk_cross.png", img)
    # ledge marker (dashes + up arrow)
    img = Image.new("L", (S, S), 0); d = ImageDraw.Draw(img)
    for x in range(20, 236, 44):
        chalk_stroke(d, wobble_line((x, 200), (x + 28, 198), 3, 2, rng), 8, rng)
    chalk_stroke(d, wobble_line((128, 170), (128, 50), 6, 3, rng), 8, rng)
    chalk_stroke(d, wobble_line((128, 50), (95, 85), 3, 2, rng), 8, rng)
    chalk_stroke(d, wobble_line((128, 50), (160, 85), 3, 2, rng), 8, rng)
    save_chalk("chalk_ledge.png", img)
    # crack (zigzag)
    img = Image.new("L", (S, S), 0); d = ImageDraw.Draw(img)
    pts = [(128 + rng.normal() * 30, y) for y in range(10, 250, 30)]
    chalk_stroke(d, pts, 10, rng)
    chalk_stroke(d, wobble_circle(128, 128, 115, rng, 1.05), 7, rng)
    save_chalk("chalk_crack.png", img)
    # twins (two stick figures holding hands) - Bindu's signature
    img = Image.new("L", (S, S), 0); d = ImageDraw.Draw(img)
    for cx in (85, 171):
        chalk_stroke(d, wobble_circle(cx, 60, 22, rng), 6, rng)
        chalk_stroke(d, wobble_line((cx, 82), (cx, 160), 4, 2, rng), 6, rng)
        chalk_stroke(d, wobble_line((cx, 160), (cx - 25, 220), 3, 2, rng), 6, rng)
        chalk_stroke(d, wobble_line((cx, 160), (cx + 25, 220), 3, 2, rng), 6, rng)
    chalk_stroke(d, wobble_line((40, 110), (216, 110), 8, 3, rng), 6, rng)
    save_chalk("chalk_twins.png", img)
    # eye (Bindu sees)
    img = Image.new("L", (S, S), 0); d = ImageDraw.Draw(img)
    top = [(30 + i * 196 / 12, 128 - math.sin(i / 12 * math.pi) * 60 + rng.normal() * 2) for i in range(13)]
    bot = [(30 + i * 196 / 12, 128 + math.sin(i / 12 * math.pi) * 55 + rng.normal() * 2) for i in range(13)]
    chalk_stroke(d, top, 7, rng); chalk_stroke(d, bot, 7, rng)
    chalk_stroke(d, wobble_circle(128, 128, 30, rng), 7, rng)
    save_chalk("chalk_eye.png", img)
    # rings (sound)
    img = Image.new("L", (S, S), 0); d = ImageDraw.Draw(img)
    for r in (40, 75, 110):
        chalk_stroke(d, wobble_circle(128, 128, r, rng, 1.0, 50), 5, rng)
    save_chalk("chalk_rings.png", img)


def handprint():
    S = 256
    rng = np.random.default_rng(121)
    img = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(img)
    d.ellipse([70, 110, 190, 230], fill=255)
    fingers = [(-50, -20, 0.8), (-22, -70, 1.0), (10, -80, 1.05), (40, -65, 0.95), (68, -30, 0.75)]
    for fx, fy, l in fingers:
        x0, y0 = 128 + fx * 0.6, 150
        x1, y1 = 128 + fx * 1.2, 150 + fy * 1.25 * l - 20
        for t in np.linspace(0, 1, 30):
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            r = 15 * (1 - t * 0.25)
            d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    a = np.asarray(img.filter(ImageFilter.GaussianBlur(2))).astype(float) / 255.0
    lines = band(S, 30, 90, 122)
    a = np.clip(a * (0.75 + 0.35 * lines), 0, 1)
    rgba = np.zeros((S, S, 4))
    rgba[..., 0] = 0.42 * (0.8 + 0.3 * lines)
    rgba[..., 1] = 0.22 * (0.8 + 0.3 * lines)
    rgba[..., 2] = 0.13
    rgba[..., 3] = a
    Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "handprint.png"))
    print("wrote handprint.png")


def soft_particle():
    S = 128
    yy, xx = np.mgrid[0:S, 0:S] / (S - 1) * 2 - 1
    r = np.sqrt(xx * xx + yy * yy)
    a = np.clip(1 - r, 0, 1) ** 2
    n = fnoise(S, 2.5, 131)
    rgba = np.stack([np.ones_like(a), np.ones_like(a), np.ones_like(a), a * (0.6 + 0.4 * n)], -1)
    Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "puff.png"))
    a2 = np.clip(1 - r, 0, 1) ** 4
    rgba = np.stack([np.ones_like(a2)] * 3 + [a2], -1)
    Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "spark.png"))
    # moth wing sprite
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([10, 30, 62, 100], fill=(40, 52, 120, 230))
    d.ellipse([66, 30, 118, 100], fill=(40, 52, 120, 230))
    d.ellipse([22, 50, 44, 72], fill=(150, 160, 220, 200))
    d.ellipse([84, 50, 106, 72], fill=(150, 160, 220, 200))
    d.rectangle([60, 35, 68, 100], fill=(15, 15, 30, 255))
    img.save(os.path.join(OUT, "moth.png"))
    print("wrote particles")


if __name__ == "__main__":
    terracotta(); silt(); limewash(); brick(); soot(); wetclay(); rope(); indigo()
    ochre_cloth(); skin(); glaze(); chalk_marks(); handprint(); soft_particle()
