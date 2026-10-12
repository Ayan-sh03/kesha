#!/usr/bin/env python3
"""Procedural audio for Dwaar.

The concept bible says the score is made from clay-pot drums, bells, a clay
whistle and a drone, and that all music comes from inside the world. Every
sound in the game is synthesised here; nothing is recorded. Run:

    python3 tools/gen_audio.py            # everything
    python3 tools/gen_audio.py music      # only the score
    python3 tools/gen_audio.py sfx voice  # only sfx + voices

Requires numpy, scipy, ffmpeg (for ogg) and espeak-ng (for voices).
"""
import os
import sys
import math
import subprocess
import tempfile
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
RNG = np.random.default_rng(5)

# Just-intonation degrees, relative to Sa.
DEG = {"S": 1.0, "r": 16 / 15, "R": 9 / 8, "g": 6 / 5, "G": 5 / 4, "m": 4 / 3, "M": 45 / 32,
       "P": 3 / 2, "d": 8 / 5, "D": 5 / 3, "n": 9 / 5, "N": 15 / 8}
SA = 146.83  # D3


def note(sw, octave=0):
    """'G' -> freq, '.D' -> lower octave, "S'" -> upper octave."""
    o = octave
    while sw.startswith("."):
        o -= 1
        sw = sw[1:]
    while sw.endswith("'"):
        o += 1
        sw = sw[:-1]
    return SA * DEG[sw] * (2 ** o)


# ================================================================ helpers
def secs(n):
    return np.arange(n) / SR


def stereo(n):
    return np.zeros((n, 2))


def place(buf, sig, t, gain=1.0, pan=0.0):
    """Add mono or stereo sig to buf at time t (s), constant-power pan."""
    i = int(t * SR)
    if i >= len(buf):
        return
    if sig.ndim == 1:
        a = (pan + 1) * math.pi / 4
        s = np.stack([sig * math.cos(a), sig * math.sin(a)], -1)
    else:
        s = sig
    j = min(len(buf), i + len(s))
    if i < 0:
        s = s[-i:]
        i = 0
    buf[i:j] += s[: j - i] * gain


def bp(x, lo, hi, order=2):
    lo = max(lo, 20)
    hi = min(hi, SR / 2 - 100)
    b, a = signal.butter(order, [lo / (SR / 2), hi / (SR / 2)], "band")
    return signal.lfilter(b, a, x, axis=0)


def lp(x, f, order=2):
    b, a = signal.butter(order, min(f, SR / 2 - 100) / (SR / 2), "low")
    return signal.lfilter(b, a, x, axis=0)


def hp(x, f, order=2):
    b, a = signal.butter(order, max(f, 20) / (SR / 2), "high")
    return signal.lfilter(b, a, x, axis=0)


def padmix(*sigs):
    """Sum signals of different lengths (zero-padded)."""
    n = max(len(x) for x in sigs)
    out = np.zeros(n)
    for x in sigs:
        out[: len(x)] += x
    return out


def fit(x, n):
    return x[:n] if len(x) >= n else np.concatenate([x, np.zeros(n - len(x))])


def noise(n, rng=RNG):
    return rng.normal(size=n)


def adsr(n, a=0.01, d=0.1, s=0.7, r=0.2):
    t = secs(n)
    dur = n / SR
    e = np.ones(n) * s
    e = np.where(t < a, t / max(a, 1e-4), e)
    e = np.where((t >= a) & (t < a + d), 1 - (1 - s) * (t - a) / max(d, 1e-4), e)
    rel_start = max(dur - r, a + d)
    e = np.where(t >= rel_start, s * np.clip(1 - (t - rel_start) / max(r, 1e-4), 0, 1), e)
    return e


def phase_of(freq):
    """freq: array -> phase (radians) by integrating."""
    return 2 * np.pi * np.cumsum(freq) / SR


def make_ir(dur, decay, dark=0.5, seed=0, pre=0.01):
    """Stereo impulse response: decorrelated noise, frequency-dependent decay."""
    rng = np.random.default_rng(seed)
    n = int(dur * SR)
    t = secs(n)
    out = np.zeros((n, 2))
    bands = [(20, 300, 1.0), (300, 1500, 0.85), (1500, 5000, 0.6 - dark * 0.3), (5000, 16000, 0.4 - dark * 0.35)]
    for lo, hi, k in bands:
        for c in range(2):
            nz = bp(rng.normal(size=n), lo, hi)
            out[:, c] += nz * np.exp(-t / (decay * max(k, 0.05)))
    p = int(pre * SR)
    out = np.concatenate([np.zeros((p, 2)), out])
    out /= np.sqrt(np.sum(out ** 2) / 2)
    return out


IR_CACHE = {}


def reverb(x, kind="cave", wet=0.35):
    if kind not in IR_CACHE:
        cfg = {"cave": (6.0, 2.4, 0.8, 1), "village": (2.5, 0.7, 0.4, 2), "hall": (8.0, 3.2, 0.6, 3),
               "small": (1.2, 0.25, 0.5, 4), "field": (3.5, 1.1, 0.3, 5), "kiln": (4.0, 1.4, 0.9, 6)}[kind]
        IR_CACHE[kind] = make_ir(cfg[0], cfg[1], cfg[2], cfg[3])
    ir = IR_CACHE[kind]
    if x.ndim == 1:
        x = np.stack([x, x], -1)
    y = np.zeros((len(x) + len(ir) - 1, 2))
    for c in range(2):
        y[:, c] = signal.fftconvolve(x[:, c], ir[:, c])
    out = np.zeros_like(y)
    out[: len(x)] = x * (1 - wet * 0.5)
    out += y * wet * 0.25
    return out


def loopify(buf, L):
    """Fold the tail past L back onto the start so the track loops seamlessly."""
    n = int(L * SR)
    out = buf[:n].copy()
    tail = buf[n:]
    k = min(len(tail), n)
    out[:k] += tail[:k]
    return out


def master(x, target_rms=0.12, ceiling=0.95):
    rms = np.sqrt(np.mean(x ** 2)) + 1e-9
    x = x * (target_rms / rms)
    x = np.tanh(x / ceiling) * ceiling
    return x


def trim_tail(x, thresh=0.0025, keep=0.05):
    """Cut the inaudible end of a reverb tail, with a short fade."""
    a = np.abs(x) if x.ndim == 1 else np.abs(x).max(1)
    idx = np.nonzero(a > thresh)[0]
    if len(idx) == 0:
        return x
    end = min(len(x), idx[-1] + int(keep * SR))
    x = x[:end].copy()
    f = min(end, int(keep * SR))
    ramp = np.linspace(1, 0, f)
    x[-f:] = (x[-f:].T * ramp).T
    return x


def write_wav(path, x, trim=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    x = np.clip(x, -1, 1)
    if trim:
        x = trim_tail(x)
    wavfile.write(path, SR, (x * 32767).astype(np.int16))


def write_ogg(path, x, q=5, trim=False):
    if trim:
        x = trim_tail(np.clip(x, -1, 1))
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmp = f.name
    write_wav(tmp, x)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(q), path],
                   check=True)
    os.remove(tmp)
    print("wrote", os.path.relpath(path, ROOT))


# ================================================================ instruments
def ghatam(stroke, base=180.0, rng=RNG, vel=1.0):
    """Clay-pot drum. Strokes: ge (bass bend), dha, ta, ka, tin."""
    dur = {"ge": 0.9, "dha": 0.45, "ta": 0.18, "ka": 0.1, "tin": 0.4, "boom": 1.6}[stroke]
    n = int(dur * SR)
    t = secs(n)
    out = np.zeros(n)
    if stroke in ("ge", "dha", "boom"):
        f0 = base * (0.42 if stroke != "boom" else 0.28)
        bend = f0 * (1 + 0.45 * (1 - np.exp(-t / 0.18))) if stroke == "ge" else f0 * (1 + 0.6 * np.exp(-t / 0.03))
        ph = phase_of(bend)
        dec = 0.35 if stroke == "ge" else (0.18 if stroke == "dha" else 0.6)
        out += np.sin(ph) * np.exp(-t / dec)
        out += 0.3 * np.sin(2.01 * ph) * np.exp(-t / (dec * 0.5))
        thump = lp(noise(n, rng), 300) * np.exp(-t / 0.02) * 2.5
        out += thump
    if stroke in ("dha", "tin", "ta"):
        modes = [(1.0, 0.09), (1.58, 0.06), (2.31, 0.045), (3.1, 0.03)]
        f = base * (2.0 if stroke == "tin" else 1.6)
        for r, d in modes:
            out += 0.35 * np.sin(2 * np.pi * f * r * t + rng.random() * 6) * np.exp(-t / (d * (2.5 if stroke == "tin" else 1)))
    if stroke in ("ta", "ka", "dha"):
        slap = bp(noise(n, rng), 1800, 6500) * np.exp(-t / (0.018 if stroke != "ka" else 0.008))
        out += slap * (1.6 if stroke == "ta" else 0.9)
    if stroke == "ka":
        out += np.sin(2 * np.pi * base * 3.3 * t) * np.exp(-t / 0.015) * 0.6
    out *= vel
    return out * 0.6


def ghungroo(n_bells=8, rng=RNG, spread=0.03, bright=1.0):
    dur = 0.5
    n = int(dur * SR)
    out = np.zeros(n)
    for _ in range(n_bells):
        st = int(rng.random() * spread * SR)
        f = rng.uniform(3200, 7800) * bright
        d = rng.uniform(0.04, 0.16)
        m = n - st
        t = secs(m)
        b = (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 1.48 * t + 1) + 0.3 * np.sin(2 * np.pi * f * 2.1 * t)) * np.exp(-t / d)
        out[st:] += b * rng.uniform(0.3, 1.0)
    out += hp(noise(n, rng), 6000) * np.exp(-secs(n) / 0.02) * 0.3
    return out * 0.18


def brass_bell(f=880.0, dur=4.0, rng=RNG, vel=1.0):
    n = int(dur * SR)
    t = secs(n)
    parts = [(1.0, 1.0, 1.0), (2.0, 0.5, 0.7), (2.76, 0.6, 0.55), (4.07, 0.35, 0.4), (5.4, 0.25, 0.28), (6.8, 0.15, 0.2), (0.5, 0.25, 1.4)]
    out = np.zeros(n)
    for r, a, dk in parts:
        for det in (-0.6, 0.6):
            out += a * np.sin(2 * np.pi * (f * r + det * r) * t + rng.random() * 6) * np.exp(-t / (dur * 0.35 * dk))
    strike = bp(noise(n, rng), 2000, 9000) * np.exp(-t / 0.004)
    return (out * 0.12 + strike * 0.2) * vel


def pluck(freqs, dur, rng=RNG, bright=1.0, decay=1.4, buzz=0.3, harmonics=28):
    """Additive plucked string; freqs is a scalar or a per-sample contour (for meend slides)."""
    n = int(dur * SR)
    t = secs(n)
    f = np.full(n, freqs) if np.isscalar(freqs) else freqs[:n]
    ph = phase_of(f)
    out = np.zeros(n)
    for k in range(1, harmonics + 1):
        if np.mean(f) * k > SR / 2 - 500:
            break
        a = (1.0 / k) * (bright ** (k / 8))
        a *= 1 + buzz * np.sin(k * 0.7)
        d = decay / (1 + 0.18 * k)
        out += a * np.sin(k * ph * (1 + 0.0004 * k) + rng.random()) * np.exp(-t / d)
    atk = np.clip(t / 0.003, 0, 1)
    return out * atk * 0.25


def tanpura_pluck(f, dur=6.0, rng=RNG):
    """Drone pluck with the moving formant (jawari shimmer)."""
    n = int(dur * SR)
    t = secs(n)
    out = np.zeros(n)
    centre = 30 * np.exp(-t / 2.5) + 3  # formant harmonic number falls over the note
    for k in range(1, 42):
        if f * k > 12000:
            break
        a = np.exp(-((k - centre) ** 2) / 30.0) * 0.8 + 0.25 / k
        out += a * np.sin(2 * np.pi * f * k * t + rng.random() * 6)
    env = np.clip(t / 0.01, 0, 1) * np.exp(-t / (dur * 0.45))
    return out * env * 0.08


def whistle(contour, rng=RNG, breathy=0.25):
    """Clay whistle (ocarina-like) from a per-sample frequency contour. contour<=0 = silence."""
    n = len(contour)
    on = (contour > 0).astype(float)
    on_s = lp(on, 25)
    f = np.where(contour > 0, contour, np.maximum.accumulate(np.where(contour > 0, contour, 0)))
    f = np.where(f <= 0, 400, f)
    vib = 1 + 0.007 * np.sin(2 * np.pi * 5.2 * secs(n)) * np.clip(lp(on, 1.5) * 1.5, 0, 1)
    ph = phase_of(f * vib)
    tone = np.sin(ph) + 0.06 * np.sin(2 * ph) + 0.02 * np.sin(3 * ph)
    br = bp(noise(n, rng), 800, 4000) * breathy
    return (tone + br) * on_s * 0.22


def heartbeat(rng=RNG):
    n = int(0.9 * SR)
    t = secs(n)
    out = np.zeros(n)
    for st, g in ((0.0, 1.0), (0.24, 0.65)):
        i = int(st * SR)
        tt = secs(n - i)
        f = 48 * (1 + 0.8 * np.exp(-tt / 0.02))
        out[i:] += g * np.sin(phase_of(f)) * np.exp(-tt / 0.09)
    return lp(out, 200) * 0.9


def breath(dur, rng=RNG, rise=True):
    n = int(dur * SR)
    t = secs(n)
    env = (t / dur) ** 2 if rise else np.sin(np.pi * t / dur) ** 2
    nz = noise(n, rng)
    a = bp(nz, 300, 1200) * 0.6 + bp(nz, 1200, 3500) * 0.4
    return a * env * 0.35


def drip(rng=RNG, f0=None):
    f0 = f0 or rng.uniform(700, 1400)
    n = int(0.25 * SR)
    t = secs(n)
    f = f0 * np.exp(t / 0.03 * 0.8)
    f = np.minimum(f, f0 * 3.2)
    s = np.sin(phase_of(f)) * np.exp(-t / 0.045)
    s[:30] += rng.normal(size=30) * 0.4
    return s * 0.35


def crackle(dur, density=30, rng=RNG):
    n = int(dur * SR)
    out = np.zeros(n)
    k = int(dur * density)
    for _ in range(k):
        i = rng.integers(0, n - 2000)
        m = rng.integers(40, 1600)
        out[i:i + m] += rng.normal(size=m) * np.exp(-np.arange(m) / (m / 5)) * rng.uniform(0.1, 1.0)
    out = hp(out, 900)
    roar = lp(noise(n, rng), 400) * 0.25 * (1 + 0.5 * lp(noise(n, rng), 2))
    return out * 0.5 + roar


def wind(dur, rng=RNG, strength=1.0):
    n = int(dur * SR)
    nz = noise(n, rng)
    mod = lp(noise(n, rng), 0.3)
    mod = (mod - mod.min()) / (mod.max() - mod.min() + 1e-9)
    lo = lp(nz, 500) * (0.4 + mod)
    hi = bp(nz, 900, 2600) * (mod ** 2) * 0.5
    return (lo + hi) * 0.4 * strength


def distorted_drone(f_contour, rng=RNG, drive=3.0):
    n = len(f_contour)
    ph = phase_of(f_contour)
    s = np.zeros(n)
    for k in range(1, 12):
        s += np.sin(k * ph + k * 0.3) / k
    s2 = np.sin(phase_of(f_contour * 1.007)) * 0.5
    x = np.tanh((s + s2) * drive)
    return lp(x, 1800) * 0.2


def wire_rasp(dur=1.4, rng=RNG):
    n = int(dur * SR)
    t = secs(n)
    nz = noise(n, rng)
    grain = (np.sin(2 * np.pi * (60 + 140 * t / dur) * t) > 0.2).astype(float)
    s = bp(nz, 1500, 6000) * (0.4 + 0.6 * grain) * np.sin(np.pi * t / dur) ** 0.5
    s += bp(nz, 300, 900) * 0.4 * np.sin(np.pi * t / dur)
    return s * 0.5


def rope_creak(rng=RNG, dur=0.6):
    n = int(dur * SR)
    t = secs(n)
    rate = 40 + 60 * np.sin(np.pi * t / dur)
    pulses = (np.sin(phase_of(rate)) > 0.97).astype(float)
    s = signal.lfilter([1], [1, -1.6, 0.8], pulses)  # resonant body
    s = bp(s, 300, 2500)
    return s / (np.max(np.abs(s)) + 1e-9) * 0.35


def rain(dur, rng=RNG, heavy=1.0):
    n = int(dur * SR)
    nz = noise(n, rng)
    base = bp(nz, 400, 9000) * 0.25 + lp(nz, 300) * 0.15
    drops = np.zeros(n)
    for _ in range(int(dur * 400 * heavy)):
        i = rng.integers(0, n - 800)
        m = rng.integers(60, 600)
        drops[i:i + m] += rng.normal(size=m) * np.exp(-np.arange(m) / (m / 6)) * rng.uniform(0.05, 0.4)
    return (base + hp(drops, 1500)) * heavy


def thunder(rng=RNG):
    n = int(7 * SR)
    t = secs(n)
    nz = noise(n, rng)
    env = np.exp(-t / 1.8) * (1 + 2 * lp(np.abs(noise(n, rng)), 4))
    crack = bp(nz, 800, 5000) * np.exp(-t / 0.15)
    return (lp(nz, 180) * env * 1.4 + crack * 0.6) * 0.5


def frog(rng=RNG):
    n = int(0.35 * SR)
    t = secs(n)
    rate = rng.uniform(25, 45)
    am = (np.sin(2 * np.pi * rate * t) > 0).astype(float)
    tone = np.sin(2 * np.pi * rng.uniform(300, 600) * t) + 0.5 * np.sin(2 * np.pi * rng.uniform(900, 1300) * t)
    return lp(tone * am, 2000) * np.sin(np.pi * t / 0.35) * 0.2


# ================================================================ rhythm
# 8-beat cycle (like a village keherwa): strokes per half-beat (16 slots)
KEHERWA = ["ge", None, "ta", "ka", "dha", None, "ta", None, "ge", "ka", "ta", None, "dha", "ka", "tin", None]
KEHERWA_FILL = ["ge", "ka", "ta", "ka", "dha", "ta", "ta", "ka", "ge", "ta", "dha", "ka", "ge", "ta", "dha", "tin"]


def drum_layer(buf, cycles, beat, pattern, base=180.0, gain=1.0, start=0.0, fill_every=4,
               swing=0.06, humanise=0.008, rng=RNG, pan=0.0, skip=0.0):
    half = beat / 2
    for c in range(cycles):
        pat = KEHERWA_FILL if (fill_every and c % fill_every == fill_every - 1) else pattern
        for i, st in enumerate(pat):
            if st is None or rng.random() < skip:
                continue
            t = start + c * beat * 8 + i * half + (swing * half if i % 2 else 0) + rng.normal() * humanise
            vel = (1.0 if i % 4 == 0 else 0.75) * rng.uniform(0.85, 1.1)
            place(buf, ghatam(st, base, rng, vel), t, gain, pan + rng.normal() * 0.05)


# ================================================================ score
GHATIYA_TUNE = [  # (swara, beats); '-' rests; '~' slide from previous
    ("G", 1), ("P", 0.5), ("G", 0.5), ("R", 1), ("S", 1), ("R", 1), ("G", 1.5), ("-", 1.5),
    ("P", 1), ("D", 0.5), ("P", 0.5), ("G", 1), ("R", 1), ("G", 1), ("R", 0.5), ("S", 0.5), (".D", 2), ("-", 0),
    ("S", 1), ("R", 1), ("G", 1), ("P", 1), ("D", 1.5), ("P", 0.5), ("G", 1), ("-", 1),
    ("G", 0.5), ("R", 0.5), ("S", 1), (".D", 1), ("S", 2.5), ("-", 2.5),
]


def tune_contour(tune, beat, octave=1, slide=0.06, transpose=1.0):
    total = sum(b for _, b in tune) * beat
    n = int(total * SR)
    c = np.zeros(n)
    t = 0.0
    prev = None
    for sw, b in tune:
        i0, i1 = int(t * SR), int((t + b * beat) * SR)
        if sw != "-":
            f = note(sw, octave) * transpose
            seg = np.full(i1 - i0, f)
            if prev is not None:
                k = min(int(slide * SR), len(seg))
                seg[:k] = np.linspace(prev, f, k)
            # tiny gap at the end so notes articulate
            g = int(0.03 * SR)
            seg[-g:] = 0
            c[i0:i1] = seg
            prev = f
        else:
            prev = None
        t += b * beat
    return c


def piece_ghatiya(variant="day"):
    bpm = {"day": 96, "night": 84, "slow": 52}[variant]
    beat = 60 / bpm
    cycles = 16 if variant != "slow" else 10
    L = cycles * 8 * beat
    buf = stereo(int((L + 8) * SR))
    rng = np.random.default_rng(100 + len(variant))
    # drone: ektara pluck on Sa every beat-ish, tanpura underneath
    dr = stereo(len(buf))
    for c in range(cycles):
        for b in range(8):
            t = c * 8 * beat + b * beat
            if variant == "day" and b in (0, 2, 3, 4, 6, 7) or variant != "day" and b in (0, 4):
                place(dr, pluck(note(".S" if b % 4 == 0 else "S"), 1.8, rng, 0.9, 1.0, 0.6), t, 0.55, -0.25)
        for k, sw in enumerate([".P", "S", "S", ".S"]):
            place(dr, tanpura_pluck(note(sw), 7.0, rng), c * 8 * beat + k * 2 * beat, 0.9, 0.3)
    # drums
    dm = stereo(len(buf))
    skip = {"day": 0.0, "night": 0.35, "slow": 0.45}[variant]
    drum_layer(dm, cycles, beat, KEHERWA, 190, 0.9, 0, 4, rng=rng, skip=skip, pan=-0.1)
    if variant == "day":  # second pot further away
        drum_layer(dm, cycles, beat, [None, None, "ka", None, None, "ka", None, "ta"] * 2, 260, 0.35, 0, 0, rng=rng, pan=0.5)
    # ankle bells on the off-beats
    bl = stereo(len(buf))
    for c in range(cycles):
        for i in range(16):
            if (i % 2 == 1 or variant == "day" and i % 4 == 0) and rng.random() > (0.2 if variant == "day" else 0.6):
                t = c * 8 * beat + i * beat / 2 + rng.normal() * 0.01
                place(bl, ghungroo(rng.integers(4, 10), rng, bright=0.8 if variant != "day" else 1.0), t, 0.8, rng.uniform(-0.6, 0.6))
    # whistle tune every 4th cycle
    wh = stereo(len(buf))
    for c in range(3, cycles, 4):
        con = tune_contour(GHATIYA_TUNE, beat, 1 if variant != "night" else 1, transpose=1.0 if variant != "slow" else 0.5 * 2)
        place(wh, whistle(con, rng, 0.3 if variant != "night" else 0.45), (c - 3) * 8 * beat, 0.9 if variant == "day" else 0.6, 0.15)
    space = {"day": "village", "night": "field", "slow": "hall"}[variant]
    mix = reverb(dr, space, 0.4)[: len(buf)] + reverb(dm, space, 0.3)[: len(buf)] + reverb(bl, space, 0.35)[: len(buf)] \
        + reverb(wh, space, 0.55 if variant != "slow" else 0.8)[: len(buf)]
    if variant == "night":
        crick = np.zeros(len(buf))
        for _ in range(int(L * 1.5)):
            i = rng.integers(0, len(buf) - SR)
            m = int(0.12 * SR)
            tt = secs(m)
            crick[i:i + m] += np.sin(2 * np.pi * 4300 * tt) * (np.sin(2 * np.pi * 30 * tt) > 0) * np.sin(np.pi * tt / 0.12) * 0.03
        mix += np.stack([crick, np.roll(crick, 4000)], -1)
    if variant == "slow":
        mix = lp(mix, 4500)
    return master(loopify(mix, L), 0.11 if variant == "day" else 0.09)


def piece_veil(variant="plain"):
    L = 72.0
    buf = stereo(int((L + 9) * SR))
    rng = np.random.default_rng(200 + len(variant))
    n = len(buf)
    t = secs(n)
    # two drones a semitone apart, never settling
    f1, f2 = note(".S"), note(".r")
    sw = 0.5 + 0.5 * np.sin(2 * np.pi * t / 18.0)
    d1 = (np.sin(2 * np.pi * f1 * t) + 0.4 * np.sin(4 * np.pi * f1 * t) + 0.2 * np.sin(6 * np.pi * f1 * t))
    d2 = (np.sin(2 * np.pi * f2 * t + 1) + 0.4 * np.sin(4 * np.pi * f2 * t) + 0.15 * np.sin(6 * np.pi * f2 * t))
    drone = np.stack([d1 * (0.6 + 0.4 * sw) + d2 * 0.5 * (1 - sw), d2 * (0.6 + 0.4 * (1 - sw)) + d1 * 0.5 * sw], -1) * 0.06
    drone = lp(drone, 900)
    mix = stereo(n) + drone
    # slow heartbeat (~50 bpm)
    hb = stereo(n)
    for k in range(int(L / 1.2)):
        place(hb, heartbeat(rng), k * 1.2, 0.9 - 0.2 * (k % 2), 0)
    mix += reverb(hb, "small", 0.25)[:n]
    # small brass bell, sparse
    bell = stereo(n)
    for k in range(0, int(L), 9):
        place(bell, brass_bell(note("S'", 2), 6, rng, 0.6), k + rng.uniform(0, 2), 0.7, rng.uniform(-0.4, 0.4))
    mix += reverb(bell, "field", 0.6)[:n]
    # breath rising behind the cloth
    br = stereo(n)
    for k in range(0, int(L), 12):
        place(br, breath(5.0, rng), k + 4, 0.8, rng.uniform(-0.3, 0.3))
    mix += reverb(br, "small", 0.4)[:n]
    if variant == "cord":
        cr = stereo(n)
        for _ in range(int(L * 0.7)):
            place(cr, rope_creak(rng, rng.uniform(0.3, 0.9)), rng.uniform(0, L), 0.5, rng.uniform(-0.8, 0.8))
        for _ in range(int(L / 3)):
            sw_ = rng.choice(["S", "r", "g", "P", "d"])
            place(cr, pluck(note(sw_), 2.5, rng, 0.6, 1.2, 0.8), rng.uniform(0, L), 0.5, rng.uniform(-0.5, 0.5))
        mix += reverb(cr, "cave", 0.5)[:n]
    return master(loopify(mix, L), 0.09)


BHAIRAV = [".N", "S", "r", "G", "m", "P", "d", "N", "S'"]


def piece_dead_river(variant="plain"):
    L = 80.0
    rng = np.random.default_rng(300 + len(variant))
    n = int((L + 9) * SR)
    t = secs(n)
    mix = stereo(n)
    # low drone
    f = note(".S") * (0.5 if variant == "low" else 1)
    dr = (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 2 * t + 1) + 0.25 * np.sin(2 * np.pi * f * 3.002 * t)) * (0.7 + 0.3 * np.sin(2 * np.pi * t / 23))
    mix += np.stack([dr, np.roll(dr, 900)], -1) * 0.05
    # dripping water in the dark
    dp = stereo(n)
    for _ in range(int(L * (1.3 if variant == "plain" else 0.8))):
        place(dp, drip(rng), rng.uniform(0, L), rng.uniform(0.2, 0.8), rng.uniform(-0.9, 0.9))
    mix += reverb(dp, "cave", 0.7)[:n]
    # plucked string wandering a mode with a flattened second, with slides (meend)
    st = stereo(n)
    pos = 1
    tt = 2.0
    while tt < L - 4:
        nxt = int(np.clip(pos + rng.choice([-2, -1, -1, 1, 1, 2]), 0, len(BHAIRAV) - 1))
        dur = rng.choice([1.2, 1.8, 2.4, 3.2])
        a, b = note(BHAIRAV[pos]), note(BHAIRAV[nxt])
        if variant == "low":
            a, b = a / 2, b / 2
        m = int(dur * SR)
        con = np.full(m, a)
        if rng.random() < 0.6:  # meend into the next note
            s0, s1 = int(m * 0.35), int(m * 0.7)
            con[s0:s1] = a * (b / a) ** np.linspace(0, 1, s1 - s0) ** 1.5
            con[s1:] = b
            pos = nxt
        place(st, pluck(con, dur, rng, 0.8, 1.6, 0.2), tt, 0.7, rng.uniform(-0.3, 0.3))
        if rng.random() < 0.3:
            pos = nxt
        tt += dur + rng.choice([0.0, 0.6, 1.5, 3.0])
    mix += reverb(st, "cave", 0.55)[:n]
    if variant == "low":
        mix = lp(mix, 2500)
        rum = lp(noise(n, rng), 60) * 0.8
        mix += np.stack([rum, rum], -1)
    return master(loopify(mix, L), 0.085)


def piece_kiln(variant="plain"):
    bpm = 72 if variant == "plain" else 84
    beat = 60 / bpm
    cycles = 12
    L = cycles * 8 * beat
    rng = np.random.default_rng(400 + len(variant))
    n = int((L + 8) * SR)
    mix = stereo(n)
    # fire crackle
    fc = crackle(L + 8, 25 if variant == "plain" else 40, rng)
    fc = lp(fc, 5000)
    mix += np.stack([fc, np.roll(fc, 3000)], -1) * 0.12
    # heavy pot drums
    dm = stereo(n)
    heavy = ["boom", None, None, "ge", "dha", None, "ge", None, "boom", None, "ta", "ge", "dha", None, "ge", "ka"]
    drum_layer(dm, cycles, beat, heavy, 120, 1.2, 0, 4 if variant == "full" else 0, rng=rng, swing=0.0)
    if variant == "full":
        drum_layer(dm, cycles, beat, [None, "ta", "ka", "ta"] * 4, 220, 0.5, 0, 0, rng=rng, pan=0.4)
    mix += reverb(dm, "kiln", 0.35)[:n]
    # distorted drone bending upward over each 4-cycle phrase
    ph_len = 4 * 8 * beat
    tt = secs(n)
    phase = (tt % ph_len) / ph_len
    f = note(".S", -1) * (2 ** (phase ** 2 * (3 if variant == "plain" else 5) / 12))
    dd = distorted_drone(f, rng, 3.0 if variant == "plain" else 5.0)
    gate = np.clip(1 - np.abs(np.diff(np.concatenate([[0], phase])) > 0.5).astype(float), 0, 1)
    mix += np.stack([dd, np.roll(dd, 500)], -1) * (0.7 if variant == "plain" else 0.9)
    # potter's wire rasp
    wr = stereo(n)
    for c in range(1, cycles, 2):
        place(wr, wire_rasp(1.4, rng), c * 8 * beat + 6 * beat, 0.6, rng.uniform(-0.6, 0.6))
    mix += reverb(wr, "kiln", 0.4)[:n]
    return master(loopify(mix, L), 0.12 if variant == "plain" else 0.13)


def piece_raakh():
    L = 96.0
    rng = np.random.default_rng(500)
    n = int((L + 10) * SR)
    mix = stereo(n)
    w = wind(L + 10, rng, 1.2)
    w2 = wind(L + 10, rng, 1.0)
    mix += np.stack([w, w2], -1) * 0.6
    # one bell falling a step at a time
    steps = ["S'", "N", "d", "P", "m", "G", "r", "S", ".N", ".d", ".P"]
    bell = stereo(n)
    for k, sw in enumerate(steps):
        place(bell, brass_bell(note(sw, 1), 7, rng, 0.8), 3 + k * 8.0, 0.8, (k % 3 - 1) * 0.3)
    mix += reverb(bell, "field", 0.7)[:n]
    # a drone that comes in after everything else has stopped
    tt = secs(n)
    env = np.clip((tt - 52) / 14, 0, 1) * np.clip((L + 4 - tt) / 6, 0, 1)
    f = note(".S", -1)
    dr = sum(np.sin(2 * np.pi * f * k * tt + k) / k for k in range(1, 8)) * env
    mix += np.stack([dr, np.roll(dr, 700)], -1) * 0.08
    # no loopify: ash is a single piece; still loop softly
    return master(loopify(mix, L), 0.08)


def piece_barsaat():
    bpm = 88
    beat = 60 / bpm
    cycles = 12
    L = cycles * 8 * beat
    rng = np.random.default_rng(600)
    n = int((L + 8) * SR)
    mix = stereo(n)
    r = rain(L + 8, rng, 0.8)
    mix += np.stack([r, np.roll(r, 2500)], -1) * 0.35
    th = stereo(n)
    place(th, thunder(rng), 6, 0.6, -0.4)
    place(th, thunder(rng), L * 0.6, 0.4, 0.5)
    mix += th
    fr = stereo(n)
    for _ in range(int(L * 0.8)):
        place(fr, frog(rng), rng.uniform(0, L), rng.uniform(0.2, 0.6), rng.uniform(-0.9, 0.9))
    mix += reverb(fr, "field", 0.3)[:n]
    dr = stereo(n)
    for c in range(cycles):
        for k, sw in enumerate([".P", "S", "S", ".S"]):
            place(dr, tanpura_pluck(note(sw), 7.0, rng), c * 8 * beat + k * 2 * beat, 0.9, 0.2)
    mix += reverb(dr, "village", 0.4)[:n]
    dm = stereo(n)
    drum_layer(dm, cycles, beat, KEHERWA, 200, 0.55, 0, 4, rng=rng, skip=0.15)
    mix += reverb(dm, "village", 0.3)[:n]
    wh = stereo(n)
    for c in (1, 5, 9):
        place(wh, whistle(tune_contour(GHATIYA_TUNE, beat, 1), rng, 0.2), c * 8 * beat, 1.0, 0.1)
    mix += reverb(wh, "field", 0.5)[:n]
    return master(loopify(mix, L), 0.11)


def piece_title():
    """Title: the curtain in the field, wind, a far bell, the village tune half-remembered."""
    L = 64.0
    rng = np.random.default_rng(700)
    n = int((L + 9) * SR)
    mix = stereo(n)
    w = wind(L + 9, rng, 0.7)
    mix += np.stack([w, np.roll(w, 5000)], -1) * 0.5
    tt = secs(n)
    f1, f2 = note(".S"), note(".r")
    d = (np.sin(2 * np.pi * f1 * tt) + 0.5 * np.sin(2 * np.pi * f2 * tt)) * (0.5 + 0.5 * np.sin(2 * np.pi * tt / 16))
    mix += np.stack([d, np.roll(d, 600)], -1) * 0.04
    bl = stereo(n)
    for k in range(0, int(L), 16):
        place(bl, brass_bell(note("S'", 1), 6, rng, 0.6), k + 2, 0.6, 0.3)
    mix += reverb(bl, "field", 0.7)[:n]
    wh = stereo(n)
    beat = 60 / 60
    con = tune_contour(GHATIYA_TUNE[:9], beat, 1)
    place(wh, whistle(con, rng, 0.5), 20, 0.6, -0.2)
    mix += reverb(wh, "hall", 0.8)[:n]
    return master(loopify(mix, L), 0.08)


def piece_boss():
    """Boss layer: driving pot drums + bells + low drone, used under every boss fight."""
    bpm = 120
    beat = 60 / bpm
    cycles = 16
    L = cycles * 8 * beat
    rng = np.random.default_rng(800)
    n = int((L + 6) * SR)
    mix = stereo(n)
    dm = stereo(n)
    drum_layer(dm, cycles, beat, ["boom", "ka", "ta", "ka", "ge", "ta", "dha", "ka", "boom", "ta", "ge", "ka", "dha", "ta", "ge", "tin"], 140, 1.1, 0, 4, rng=rng, swing=0.02)
    drum_layer(dm, cycles, beat, [None, "ta", None, "ta"] * 4, 260, 0.5, 0, 0, rng=rng, pan=0.5)
    mix += reverb(dm, "kiln", 0.3)[:n]
    bl = stereo(n)
    for c in range(cycles):
        for i in range(0, 16, 2):
            place(bl, ghungroo(10, rng, 0.02), c * 8 * beat + i * beat / 2, 0.8, rng.uniform(-0.6, 0.6))
    mix += reverb(bl, "small", 0.2)[:n]
    tt = secs(n)
    phase = (tt % (8 * 8 * beat)) / (8 * 8 * beat)
    dd = distorted_drone(note(".S", -1) * (2 ** (phase * 2 / 12)), rng, 4.0)
    mix += np.stack([dd, np.roll(dd, 400)], -1) * 0.8
    st = stereo(n)
    for c in range(0, cycles, 2):
        for k, sw in enumerate(["S", "r", "G", "m", "P", "m", "G", "r"]):
            place(st, pluck(note(sw, 1), 0.6, rng, 1.1, 0.4, 0.5), c * 8 * beat + k * beat, 0.35, 0.2)
    mix += reverb(st, "kiln", 0.35)[:n]
    return master(loopify(mix, L), 0.13)


def build_music(only=None):
    d = os.path.join(ROOT, "music")
    if only == "kiln":
        write_ogg(os.path.join(d, "kiln.ogg"), piece_kiln("plain"))
        write_ogg(os.path.join(d, "kiln_full.ogg"), piece_kiln("full"))
        return
    write_ogg(os.path.join(d, "ghatiya.ogg"), piece_ghatiya("day"))
    write_ogg(os.path.join(d, "ghatiya_night.ogg"), piece_ghatiya("night"))
    write_ogg(os.path.join(d, "ghatiya_slow.ogg"), piece_ghatiya("slow"))
    write_ogg(os.path.join(d, "veil.ogg"), piece_veil("plain"))
    write_ogg(os.path.join(d, "veil_cord.ogg"), piece_veil("cord"))
    write_ogg(os.path.join(d, "dead_river.ogg"), piece_dead_river("plain"))
    write_ogg(os.path.join(d, "dead_river_low.ogg"), piece_dead_river("low"))
    write_ogg(os.path.join(d, "kiln.ogg"), piece_kiln("plain"))
    write_ogg(os.path.join(d, "kiln_full.ogg"), piece_kiln("full"))
    write_ogg(os.path.join(d, "raakh.ogg"), piece_raakh())
    write_ogg(os.path.join(d, "barsaat.ogg"), piece_barsaat())
    write_ogg(os.path.join(d, "title.ogg"), piece_title())
    write_ogg(os.path.join(d, "boss.ogg"), piece_boss())


# ================================================================ sfx
def env_n(n, a, d):
    t = secs(n)
    return np.clip(t / max(a, 1e-4), 0, 1) * np.exp(-t / d)


def sfx(name, x, space=None, wet=0.3, gain=0.8):
    if space:
        x = reverb(x, space, wet)
        x = x.mean(1)
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    fade = min(len(x), 400)
    x[-fade:] *= np.linspace(1, 0, fade)
    write_ogg(os.path.join(ROOT, "sfx", name + ".ogg"), x, 4, True)


def build_sfx():
    rng = np.random.default_rng(900)
    # footsteps
    for k in range(4):
        n = int(0.16 * SR)
        nz = noise(n, rng)
        x = lp(nz, 1800 + k * 300) * env_n(n, 0.002, 0.025) + bp(nz, 2500, 7000) * env_n(n, 0.004, 0.04) * 0.3
        x += np.sin(2 * np.pi * (90 + k * 10) * secs(n)) * env_n(n, 0.001, 0.02) * 0.6
        sfx(f"step_dust{k}", x, gain=0.5)
        # water
        n2 = int(0.35 * SR)
        x = bp(noise(n2, rng), 500, 4000) * env_n(n2, 0.005, 0.07)
        for _ in range(5):
            i = rng.integers(0, n2 // 2)
            d = drip(rng, rng.uniform(500, 900))
            x[i:i + len(d)] += d[: n2 - i] * 0.6
        sfx(f"step_water{k}", x, gain=0.5)
        # silt / mud
        x = lp(noise(n, rng), 600) * env_n(n, 0.01, 0.05)
        x += signal.lfilter([1], [1, -1.8, 0.85], (rng.random(n) > 0.995).astype(float)) * 0.02 * env_n(n, 0.01, 0.08)
        sfx(f"step_silt{k}", x, gain=0.45)
    n = int(0.3 * SR)
    sfx("land", lp(noise(n, rng), 400) * env_n(n, 0.002, 0.06) + np.sin(2 * np.pi * 60 * secs(n)) * env_n(n, 0.002, 0.05), gain=0.7)
    n = int(0.25 * SR)
    sfx("jump", bp(noise(n, rng), 600, 3000) * env_n(n, 0.01, 0.05), gain=0.35)
    # paddle
    for k in range(3):
        n = int(0.28 * SR)
        t = secs(n)
        f = 300 + 1200 * np.sin(np.pi * t / 0.28)
        x = bp(noise(n, rng), 400, 3000) * np.sin(np.pi * t / 0.28) ** 2
        sfx(f"swing{k}", x * (0.8 + 0.1 * k), gain=0.5)
    for k in range(3):
        n = int(0.5 * SR)
        x = fit(padmix(ghatam("ta", 300 + k * 40, rng), ghatam("ka", 500, rng) * 0.6), n)
        x += bp(noise(n, rng), 1500, 7000) * env_n(n, 0.001, 0.03)
        sfx(f"hit_clay{k}", x, "small", 0.2, 0.8)
    # big shatter: many shards
    n = int(1.6 * SR)
    x = np.zeros(n)
    for _ in range(70):
        i = rng.integers(0, int(0.6 * SR))
        m = rng.integers(400, 4000)
        tt = secs(m)
        f = rng.uniform(900, 4500)
        x[i:i + m] += np.sin(2 * np.pi * f * tt) * np.exp(-tt / rng.uniform(0.01, 0.05)) * rng.uniform(0.2, 1)
    x += lp(noise(n, rng), 300) * env_n(n, 0.002, 0.15) * 2
    sfx("shatter", x, "small", 0.3, 0.9)
    # sling
    n = int(0.4 * SR)
    t = secs(n)
    tw = np.sin(phase_of(220 * (1 + 2 * np.exp(-t / 0.02)))) * np.exp(-t / 0.08)
    wh = bp(noise(n, rng), 1200, 5000) * np.sin(np.pi * np.clip(t / 0.3, 0, 1)) ** 2 * 0.6
    sfx("sling", tw + wh, gain=0.6)
    n = int(0.3 * SR)
    sfx("pellet_hit", fit(ghatam("ka", 700, rng), n), "small", 0.2, 0.6)
    # block / parry
    n = int(0.6 * SR)
    t = secs(n)
    sfx("block", lp(noise(n, rng), 800) * env_n(n, 0.001, 0.04) + np.sin(2 * np.pi * 180 * t) * env_n(n, 0.001, 0.06), gain=0.7)
    sfx("parry", fit(brass_bell(1400, 0.6, rng), n) * 3 + bp(noise(n, rng), 2000, 8000) * env_n(n, 0.001, 0.02), "small", 0.3, 0.8)
    # hurt: a breathy grunt (formant-filtered pulse)
    def vocal(f0c, formants, dur, breath_amt=0.2, rng=rng):
        n = int(dur * SR)
        f0 = np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(f0c)), f0c)
        ph = phase_of(f0)
        src = signal.sawtooth(ph) * 0.6 + noise(n, rng) * breath_amt
        out = np.zeros(n)
        for fc, bw, g in formants:
            out += bp(src, fc - bw / 2, fc + bw / 2) * g
        return out
    for k in range(2):
        x = vocal([300, 260 - k * 20, 200], [(700, 200, 1.0), (1200, 200, 0.5), (2600, 300, 0.2)], 0.28, 0.4)
        x *= np.sin(np.pi * secs(len(x)) / 0.28) ** 0.5
        sfx(f"hurt{k}", x, "small", 0.2, 0.6)
    # Bindu's cry, heard from far below when he is hit with fired skin
    x = vocal([520, 600, 480, 380], [(850, 250, 1.0), (1300, 250, 0.6), (2900, 400, 0.25)], 0.7, 0.35)
    x *= np.sin(np.pi * secs(len(x)) / 0.7) ** 0.7
    sfx("bindu_cry", x, "cave", 0.6, 0.6)
    # Gaara: deep god voice (rumbling formant growl)
    x = vocal([55, 50, 46, 52, 44], [(300, 120, 1.0), (600, 150, 0.6), (2400, 400, 0.1)], 2.4, 0.6)
    x *= np.sin(np.pi * secs(len(x)) / 2.4) ** 0.6
    sfx("gaara_voice", x, "hall", 0.6, 0.9)
    # bells
    sfx("bell", brass_bell(1250, 2.5, rng), "village", 0.3, 0.6)
    sfx("bell_low", brass_bell(520, 4.5, rng), "field", 0.5, 0.7)
    n = int(0.6 * SR)
    snip = bp(noise(n, rng), 3000, 9000) * env_n(n, 0.0005, 0.006)
    clank = brass_bell(1250, 0.6, rng)[:n] * np.exp(-secs(n) / 0.05) * 2
    sfx("bell_cut", snip + np.roll(clank, int(0.12 * SR)), "small", 0.3, 0.7)
    # knock
    for k in range(3):
        n = int(0.5 * SR)
        x = np.zeros(n)
        for j in range(3 if k < 2 else 2):
            g = ghatam("ka", 260 + k * 30, rng)
            i = int(j * 0.13 * SR)
            x[i:i + len(g)] += g[: n - i] * 1.3
        sfx(f"knock{k}", lp(x, 2500), "small", 0.4, 0.75)
    # whisper (Mother, wordless)
    for k in range(3):
        dur = 1.6
        n = int(dur * SR)
        nz = noise(n, rng)
        formant_sweep = 900 + 600 * np.sin(np.linspace(0, 3 * np.pi + k, n))
        x = np.zeros(n)
        for seg in range(0, n, 2048):
            fc = formant_sweep[seg]
            x[seg:seg + 2048] = bp(nz[seg:seg + 2048], fc * 0.7, fc * 1.4)
        syll = (np.sin(2 * np.pi * (4 + k) * secs(n)) * 0.5 + 0.5) ** 2
        x = x * syll * np.sin(np.pi * secs(n) / dur)
        sfx(f"whisper{k}", x, "cave", 0.5, 0.55)
    sfx("breath_in", breath(1.2, rng), "small", 0.3, 0.5)
    sfx("heartbeat", heartbeat(rng), None, 0, 0.8)
    # worm hum
    n = int(2.2 * SR)
    t = secs(n)
    hum = sum(np.sin(2 * np.pi * 58 * k * t * (1 + 0.003 * k)) / k for k in range(1, 9)) * np.sin(np.pi * t / 2.2)
    hum *= 1 + 0.4 * np.sin(2 * np.pi * 7 * t)
    sfx("hum", hum, "cave", 0.4, 0.8)
    # rumble / cave-in
    n = int(3.5 * SR)
    x = lp(noise(n, rng), 120) * env_n(n, 0.3, 1.2) * 3
    for _ in range(40):
        i = rng.integers(0, n - 5000)
        g = ghatam("boom", rng.uniform(80, 200), rng)
        x[i:i + len(g)] += g[: n - i] * rng.uniform(0.2, 0.7)
    sfx("rumble", x, "cave", 0.4, 0.9)
    n = int(2.0 * SR)
    sfx("roar", lp(noise(n, rng), 250) * env_n(n, 0.15, 0.6) * 2 + distorted_drone(np.full(n, 45.0), rng, 6) * env_n(n, 0.1, 0.7), "hall", 0.5, 0.9)
    # fire
    n = int(1.4 * SR)
    t = secs(n)
    sfx("fire_whoosh", bp(noise(n, rng), 200, 2500) * np.sin(np.pi * t / 1.4) ** 2 + crackle(1.4, 50, rng) * 0.5, "kiln", 0.3, 0.8)
    n = int(2.5 * SR)
    t = secs(n)
    x = lp(noise(n, rng), 300) * env_n(n, 0.003, 0.4) * 3 + bp(noise(n, rng), 600, 4000) * env_n(n, 0.002, 0.25) + crackle(2.5, 80, rng) * np.exp(-t / 0.8)
    sfx("explode", x, "cave", 0.4, 0.95)
    n = int(1.0 * SR)
    sfx("sizzle", hp(noise(n, rng), 3000) * (0.6 + 0.4 * rng.random(n)) * env_n(n, 0.01, 0.4), None, 0, 0.4)
    # lamp
    n = int(0.9 * SR)
    t = secs(n)
    strike = bp(noise(n, rng), 1500, 6000) * env_n(n, 0.001, 0.05)
    flame = bp(noise(n, rng), 200, 1500) * np.clip((t - 0.05) / 0.1, 0, 1) * np.exp(-t / 0.5) * 0.7
    sfx("lamp_light", strike + flame, "small", 0.2, 0.6)
    n = int(2.5 * SR)
    x = np.zeros(n)
    g = ghatam("ka", 220, rng)
    x[: len(g)] += g
    b = brass_bell(note("S'", 1), 2.4, rng)
    x[int(0.12 * SR): int(0.12 * SR) + len(b)] += b[: n - int(0.12 * SR)] * 2
    sfx("lamp_set", x, "village", 0.4, 0.7)
    # curtain / cloth
    n = int(1.8 * SR)
    t = secs(n)
    mod = lp(np.abs(noise(n, rng)), 8)
    sfx("curtain", bp(noise(n, rng), 300, 3000) * mod * np.sin(np.pi * t / 1.8), "field", 0.3, 0.6)
    n = int(0.8 * SR)
    t = secs(n)
    tear = bp(noise(n, rng), 1000, 7000) * (rng.random(n) > 0.6) * np.exp(-t / 0.3)
    sfx("cloth_tear", tear, "small", 0.2, 0.7)
    # chalk
    n = int(0.9 * SR)
    t = secs(n)
    sq = bp(noise(n, rng), 2500, 7000) * (0.5 + 0.5 * np.sin(2 * np.pi * 11 * t)) ** 3 * np.sin(np.pi * t / 0.9)
    sfx("chalk", sq, "small", 0.3, 0.45)
    # Bindu taps back through the clay
    n = int(1.0 * SR)
    x = np.zeros(n)
    for j, g in enumerate((1, 0.8, 0.9)):
        k_ = ghatam("ka", 400, rng) * g
        i = int((0.0, 0.18, 0.36)[j] * SR)
        x[i:i + len(k_)] += k_
    sfx("tap", lp(x, 1800), "cave", 0.6, 0.6)
    # water pour
    n = int(1.6 * SR)
    t = secs(n)
    x = bp(noise(n, rng), 400, 3000) * np.sin(np.pi * t / 1.6) * 0.5
    for _ in range(40):
        i = rng.integers(0, n - 12000)
        d = drip(rng, rng.uniform(400, 1000))
        x[i:i + len(d)] += d * 0.5
    sfx("pour", x, "small", 0.3, 0.6)
    sfx("drip", drip(rng), "cave", 0.5, 0.5)
    # door given: deep tone + bell + whisper
    n = int(5.0 * SR)
    t = secs(n)
    tone = sum(np.sin(2 * np.pi * note(".S", -1) * k * t) / k for k in range(1, 6)) * np.exp(-t / 2.0)
    x = tone * 0.8
    b = brass_bell(note("r'", 1), 4.5, rng)
    x[: len(b)] += b * 1.5
    x += breath(5.0, rng, False) * 0.8
    sfx("door_give", x, "hall", 0.6, 0.9)
    # knot untie: rope creak + reverse swell
    n = int(2.2 * SR)
    t = secs(n)
    rc = rope_creak(rng, 1.0)
    x = np.zeros(n)
    x[: len(rc)] += rc
    sw = brass_bell(note("S'", 1), 1.6, rng)[::-1]
    x[n - len(sw) - 2000: n - 2000] += sw * 1.5
    sfx("knot_untie", x, "cave", 0.4, 0.75)
    # moths
    n = int(1.5 * SR)
    t = secs(n)
    flap = (np.sin(2 * np.pi * 28 * t + 3 * np.sin(2 * np.pi * 3 * t)) > 0.6).astype(float)
    sfx("moths", lp(bp(noise(n, rng), 200, 1500) * flap, 1500) * np.sin(np.pi * t / 1.5), "field", 0.3, 0.4)
    # clay creak (figures moving, stop-motion)
    for k in range(3):
        n = int(0.5 * SR)
        x = rope_creak(rng, 0.5) * 0.7 + lp(noise(n, rng), 300) * env_n(n, 0.02, 0.15) * 0.5
        sfx(f"creak{k}", x[:n], "hall", 0.4, 0.6)
    # bull hooves charge
    n = int(1.2 * SR)
    x = np.zeros(n)
    for j in range(8):
        g = ghatam("dha", 110, rng)
        i = int(j * 0.14 * SR)
        x[i:i + len(g)] += g[: n - i] * (0.6 + j * 0.06)
    sfx("charge", x, "hall", 0.3, 0.85)
    # swimmer burst
    n = int(1.0 * SR)
    t = secs(n)
    sfx("burst", lp(noise(n, rng), 900) * env_n(n, 0.005, 0.2) * 2 + bp(noise(n, rng), 800, 3000) * env_n(n, 0.01, 0.3), "cave", 0.4, 0.8)
    # rake sweep
    n = int(1.4 * SR)
    t = secs(n)
    sfx("rake", bp(noise(n, rng), 300, 2000) * np.sin(np.pi * t / 1.4) + crackle(1.4, 90, rng) * 0.7, "kiln", 0.3, 0.8)
    sfx("wire", wire_rasp(1.6, rng), "hall", 0.4, 0.8)
    # gas hiss
    n = int(1.6 * SR)
    sfx("gas", hp(noise(n, rng), 2000) * 0.5 * np.sin(np.pi * secs(n) / 1.6), None, 0, 0.35)
    # ui
    n = int(0.6 * SR)
    sfx("ui_move", fit(ghatam("ka", 600, rng), int(0.1 * SR)), "small", 0.3, 0.35)
    sfx("ui_select", fit(brass_bell(note("P'", 1), 1.0, rng), n), "small", 0.4, 0.5)
    sfx("checkpoint", brass_bell(note("S'", 1), 3.0, rng) + brass_bell(note("P'", 1), 3.0, rng) * 0.6, "village", 0.5, 0.6)
    sfx("thunder", thunder(rng), None, 0, 0.9)
    sfx("pickup", brass_bell(note("G'", 2), 0.8, rng), "small", 0.3, 0.35)
    # crowd breath (praying crowd, every door shut): many held breaths released
    n = int(4.0 * SR)
    x = np.zeros(n)
    for _ in range(25):
        b = breath(rng.uniform(0.8, 1.6), rng, False)
        i = rng.integers(0, n - len(b))
        x[i:i + len(b)] += b * rng.uniform(0.2, 0.6)
    sfx("crowd_breath", x, "village", 0.4, 0.5)
    # splash (boat into the Mouth / falls into water)
    n = int(1.8 * SR)
    x = lp(noise(n, rng), 1200) * env_n(n, 0.005, 0.3) * 1.5
    for _ in range(30):
        i = rng.integers(0, int(0.8 * SR))
        d = drip(rng, rng.uniform(300, 900))
        x[i:i + len(d)] += d * 0.7
    sfx("splash", x, "cave", 0.4, 0.8)
    # ambience loops (ogg, longer)
    amb = os.path.join(ROOT, "sfx")
    L = 30.0
    def loop_amb(name, mono_or_st, wet_space=None):
        x = mono_or_st
        if x.ndim == 1:
            x = np.stack([x, np.roll(x, 5000)], -1)
        if wet_space:
            x = reverb(x, wet_space, 0.4)
        x = loopify(x, L)
        write_ogg(os.path.join(amb, name + ".ogg"), master(x, 0.08), 4)
    loop_amb("amb_wind", wind(L + 4, rng))
    loop_amb("amb_rain", rain(L + 4, rng, 1.0))
    loop_amb("amb_fire", crackle(L + 4, 40, rng))
    dp = np.zeros(int((L + 6) * SR))
    for _ in range(50):
        d = drip(rng)
        i = rng.integers(0, len(dp) - len(d))
        dp[i:i + len(d)] += d * rng.uniform(0.2, 0.8)
    dp += lp(noise(len(dp), rng), 80) * 0.15
    loop_amb("amb_cave", dp, "cave")


# ================================================================ voices
def espeak(text, voice="en", pitch=50, speed=150, variant=None):
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmp = f.name
    v = voice + ("+" + variant if variant else "")
    subprocess.run(["espeak-ng", "-v", v, "-p", str(pitch), "-s", str(speed), "-w", tmp, text], check=True)
    sr, x = wavfile.read(tmp)
    os.remove(tmp)
    x = x.astype(float) / 32768.0
    if x.ndim > 1:
        x = x.mean(1)
    # resample to SR
    x = signal.resample_poly(x, SR, sr)
    return x


def pitch_shift(x, ratio):
    """Crude: resample (changes duration too) - fine for ghostly layers."""
    up, down = int(1000 / ratio), 1000
    return signal.resample_poly(x, up, down)


def build_voice():
    d = os.path.join(ROOT, "voice")
    rng = np.random.default_rng(1000)
    # Kaki's three words: Tesu says them aloud, all five doors open
    words = {"shut": ("bund", "hi"), "open": ("khulo", "hi"), "break": ("toot", "hi")}
    for key, (txt, lang) in words.items():
        a = espeak(txt, lang, 80, 120, "m3")
        b = pitch_shift(a, 0.5)
        n = max(len(a), len(b))
        a = np.pad(a, (0, n - len(a)))
        b = np.pad(b, (0, n - len(b)))
        x = a + b * 0.45
        x = np.concatenate([x, np.zeros(int(0.4 * SR))])
        y = reverb(x, "hall", 0.55).mean(1)
        sfx_path = os.path.join(d, f"word_{key}.wav")
        y = y / (np.max(np.abs(y)) + 1e-9) * 0.9
        write_ogg(sfx_path.replace(".wav", ".ogg"), y, 4, True)
        print("wrote voice/word_" + key)
        # Bindu says it for him through a handprint: farther, whispered
        w = espeak(txt, lang, 90, 110, "whisper")
        w = np.concatenate([w, np.zeros(int(0.6 * SR))])
        w = lp(w, 3500)
        y = reverb(w, "cave", 0.7).mean(1)
        y = y / (np.max(np.abs(y)) + 1e-9) * 0.8
        write_ogg(os.path.join(d, f"bindu_{key}.ogg"), y, 4, True)
        print("wrote voice/bindu_" + key)
    # The Veiled Mother: whispered, layered, very close
    lines = {
        "mother_offer": "Give me a door, little potter. And I will carry you back.",
        "mother_every": "Every time.",
        "mother_which": "Which door?",
        "mother_kept": "Kept.",
        "mother_refuse": "Then go back. Empty handed.",
        "mother_name": "Bindu.",
        "mother_terms": "Name your terms.",
        "mother_house": "A whole house.",
    }
    for key, txt in lines.items():
        layers = []
        for p, v in ((40, "whisper"), (30, "whisperf"), (55, "whisper")):
            try:
                layers.append(espeak(txt, "en", p, 105, v))
            except subprocess.CalledProcessError:
                layers.append(espeak(txt, "en", p, 105, "whisper"))
        n = max(len(l) for l in layers)
        st = np.zeros((n + int(0.3 * SR), 2))
        for i, l in enumerate(layers):
            off = int(i * 0.012 * SR)
            pan = (-0.6, 0.6, 0.0)[i]
            a = (pan + 1) * math.pi / 4
            st[off:off + len(l), 0] += l * math.cos(a) * (0.6 if i else 1.0)
            st[off:off + len(l), 1] += l * math.sin(a) * (0.6 if i else 1.0)
        st = lp(st, 5000)
        y = reverb(st, "small", 0.45)
        y = y / (np.max(np.abs(y)) + 1e-9) * 0.85
        write_ogg(os.path.join(d, key + ".ogg"), y, 4, True)
        print("wrote voice/" + key)
    # Bindu's small spoken lines (whispered child)
    blines = {"bindu_tesu": "Tesu.", "bindu_here": "I'm here.", "bindu_see": "I can see.", "bindu_hear": "I can hear you."}
    for key, txt in blines.items():
        w = espeak(txt, "en", 95, 120, "whisperf") if True else None
        w = np.concatenate([w, np.zeros(int(0.5 * SR))])
        y = reverb(lp(w, 4000), "cave", 0.65).mean(1)
        y = y / (np.max(np.abs(y)) + 1e-9) * 0.8
        write_ogg(os.path.join(d, key + ".ogg"), y, 4, True)
        print("wrote voice/" + key)


if __name__ == "__main__":
    what = sys.argv[1:] or ["music", "sfx", "voice"]
    if "sfx" in what:
        build_sfx()
    if "voice" in what:
        build_voice()
    if "music" in what:
        build_music()
    if "kiln" in what:
        build_music("kiln")
