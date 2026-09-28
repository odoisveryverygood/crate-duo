#!/usr/bin/env python3
"""build_fx.py -- square brat FX showcase from the Bitrig hinge takes (demo/raw/fx_*.mov/.wav).
Each effect: fold (screen dims, meter climbs, effect builds) -> snap -> drop. The background flips
orange <-> white on every drop. Cuts land on kicks so the groove never stutters.

  ~/vlogcut/.venv/bin/python3 tools/video/build_fx.py  -> demo/twitter/v3/crate_fx.mp4
"""
import os
import subprocess
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_tw3 import ORANGE, WHITE, brat_text, card, sh  # noqa: E402

RAW = os.path.expanduser("~/crate-build/demo/raw")
OUT = os.path.expanduser("~/crate-build/demo/twitter/v3")
TMP = os.path.join(OUT, "tmpfx")
os.makedirs(TMP, exist_ok=True)
S, FPS, SR = 1080, 30, 48000
TAKES = [  # name, caption during the build
    ("lpf", ["fold it."]),
    ("repeat", ["beat repeat."]),
    ("half", ["half speed."]),
    ("crush", ["bitcrush."]),
    ("dub", ["dub echo."]),
]
AFTER = ["drop it.", "drop.", "drop.", "drop.", "drop."]


def audio(name):
    r = subprocess.run(["ffmpeg", "-v", "error", "-i", os.path.join(RAW, f"fx_{name}.wav"), "-ac", "1", "-ar", str(SR),
                        "-f", "f32le", "-"], capture_output=True)
    return np.frombuffer(r.stdout, np.float32)


def env(x, lo=None, hi=None, hop=0.01):
    from scipy.signal import butter, sosfilt
    if lo:
        x = sosfilt(butter(4, lo, "highpass", fs=SR, output="sos"), x)
    if hi:
        x = sosfilt(butter(4, hi, "lowpass", fs=SR, output="sos"), x)
    h = int(SR * hop)
    n = len(x) // h
    return 20 * np.log10(np.sqrt((x[:n * h].reshape(n, h) ** 2).mean(1)) + 1e-9), hop


def snap_in_audio(x, meta):
    """Expected from the logged wall clock (music start <-> play command), refined to the biggest
    high-band jump within +-0.7 s."""
    e, hop = env(x, lo=1500)
    start = int(np.argmax(e > -80)) * hop                       # first audible sound = play
    play_wall = meta["launch"] + 6 + 0.4 + 2.5
    exp = start + (meta["snap"] + 0.1 - play_wall)
    lo, hi = int((exp - 0.7) / hop), int((exp + 0.7) / hop)
    best, t = -1e9, exp
    for i in range(max(45, lo), min(len(e) - 5, hi)):
        jump = e[i:i + 4].max() - e[i - 40:i].mean()
        if jump > best:
            best, t = jump, i * hop
    return t


def kicks(x):
    e, hop = env(x, hi=150)
    pk = [i for i in range(1, len(e) - 1) if e[i] > e[i - 1] and e[i] >= e[i + 1] and e[i] > e.max() - 14]
    out = []
    for i in pk:
        if not out or (i - out[-1]) * hop > 0.3:
            out.append(i)
    return np.array(out) * hop


def video_snap(name, approx):
    """Screen brightness jump (dim -> bright) near `approx` seconds in the screen recording."""
    mov = os.path.join(RAW, f"fx_{name}.mov")
    r = subprocess.run(["ffmpeg", "-v", "error", "-ss", str(max(0, approx - 2)), "-t", "4", "-i", mov,
                        "-vf", "fps=60,scale=160:160,format=gray", "-f", "rawvideo", "-"], capture_output=True)
    fr = np.frombuffer(r.stdout, np.uint8).reshape(-1, 160, 160)[:, 30:110, 20:140].mean((1, 2))
    d = np.diff(fr)
    return max(0, approx - 2) + (int(np.argmax(d)) + 1) / 60


def key_dark(f, bg, fixed=None):
    f = f.astype(np.float32)
    mn, mx, mean = f.min(-1), f.max(-1), f.mean(-1)
    bgm = np.median(np.concatenate([mean[:20].ravel(), mean[-20:].ravel()]))
    near = ((mx - mn) < 10) & (np.abs(mean - bgm) <= 6)
    shadow = ((mx - mn) < 10) & (mean < bgm - 6) & (mean >= bgm * 0.45)
    lab2, _ = ndimage.label(near)
    e2 = np.unique(np.concatenate([lab2[0], lab2[-1], lab2[:, 0], lab2[:, -1]]))
    core = np.isin(lab2, e2[e2 > 0])
    lab, _ = ndimage.label(near | shadow)
    edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    region = core | (np.isin(lab, edge[edge > 0]) & ndimage.binary_dilation(core, iterations=18) & shadow)
    dev = ~region
    dl, dn = ndimage.label(dev)
    if dn > 1:
        sizes = ndimage.sum(dev, dl, range(1, dn + 1))
        region |= dev & (dl != np.argmax(sizes) + 1)
    if fixed is not None:          # static camera + device: reuse the outline from a bright frame
        region = fixed
    shade = np.clip(mean / bgm, 0, 1)[..., None]
    soft = ndimage.gaussian_filter(region.astype(np.float32), 0.8)[..., None]
    return np.clip(f * (1 - soft) + bg * shade * soft, 0, 255).astype(np.uint8), ~region


def plan():
    clips = []
    for k, (name, cap) in enumerate(TAKES):
        import json
        meta = json.load(open(os.path.join(RAW, f"fx_{name}.json")))
        x = audio(name)
        sa = snap_in_audio(x, meta)
        kk = kicks(x)
        pre = 3.6 if k == 0 else 2.4
        beat = 60 / 124
        k0 = kk[kk >= sa - 0.05][0] if (kk >= sa - 0.05).any() else sa
        a_in = k0 - round((k0 - (sa - pre)) / beat) * beat       # on the kick grid, before the drop
        a_out = k0 + 3 * beat                                     # three kicks of the drop
        import json
        meta = json.load(open(os.path.join(RAW, f"fx_{name}.json")))
        sv = video_snap(name, meta["snap"] - meta["rec_start"] + 0.15)
        off = sv - sa                                    # video_time = audio_time + off
        clips.append(dict(name=name, cap=cap, after=[AFTER[k]], a_in=a_in, a_out=a_out, snap=sa, off=off, x=x))
        print(f"{name:7} snap audio {sa:.2f} video {sv:.2f}  in {a_in:.2f} out {a_out:.2f}  len {a_out - a_in:.2f}")
    return clips


def render(clips, end_dur=2.8):
    frames_path = os.path.join(TMP, "video.mov")
    enc = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{S}x{S}",
                            "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-crf", "15", "-preset", "fast",
                            "-pix_fmt", "yuv420p", frames_path], stdin=subprocess.PIPE)
    colors = [ORANGE, WHITE]
    ci = 0
    for c in clips:
        v0 = c["a_in"] + c["off"]
        dur = c["a_out"] - c["a_in"]
        n = round(dur * FPS)
        snap_rel = c["snap"] - c["a_in"]
        dec = subprocess.Popen(["ffmpeg", "-v", "error", "-ss", f"{v0:.3f}", "-t", f"{dur + 0.2:.3f}", "-i",
                                os.path.join(RAW, f"fx_{c['name']}.mov"), "-vf", f"fps={FPS},scale={S}:{S}:flags=lanczos",
                                "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
        crop = None
        bg_pre, bg_post = colors[ci % 2], colors[(ci + 1) % 2]
        cap_pre = brat_text(c["cap"], 124, WHITE if bg_pre is ORANGE else ORANGE, blur=0, xy=(58, 40))
        cap_post = brat_text(c["after"], 124, WHITE if bg_post is ORANGE else ORANGE, blur=0, xy=(58, 40))
        for i in range(n):
            buf = dec.stdout.read(S * S * 3)
            if len(buf) < S * S * 3:
                break
            fr = np.frombuffer(buf, np.uint8).reshape(S, S, 3)
            post = i / FPS >= snap_rel
            bg = bg_post if post else bg_pre
            if crop is None:
                _, dev0 = key_dark(fr, bg)
                fixed = ~dev0
            k, dev = key_dark(fr, bg, fixed)
            if crop is None:
                ys, xs = np.nonzero(dev)
                x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
                side = int(max(x1 - x0, y1 - y0) * 1.12)
                cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
                crop = (int(max(0, min(S - side, cx - side / 2))), int(max(0, min(S - side, cy - side / 2))), side)
            x, y, side = crop
            im = Image.fromarray(k[y:y + side, x:x + side]).resize((S - 40, S - 40), Image.LANCZOS)
            canvas = Image.new("RGBA", (S, S), tuple(int(v) for v in bg) + (255,))
            canvas.paste(im, (20, 110))
            canvas.alpha_composite(cap_post if post else cap_pre)
            enc.stdin.write(canvas.convert("RGB").tobytes())
        dec.stdout.close(); dec.wait()
        ci += 1
    end = card(["crate."], ORANGE, 300, sub=["one hinge. every effect.", "crateduo.vercel.app"])
    for _ in range(round(end_dur * FPS)):
        enc.stdin.write(end.tobytes())
    enc.stdin.close(); enc.wait()
    # audio: clip segments back to back (kick to kick), the last one runs on under the end card
    segs = []
    for j, c in enumerate(clips):
        a, b = int(c["a_in"] * SR), int((c["a_out"] + (end_dur if j == len(clips) - 1 else 0)) * SR)
        s = c["x"][a:b].copy()
        f = int(0.008 * SR)
        s[:f] *= np.linspace(0, 1, f)
        if j < len(clips) - 1:
            s[-f:] *= np.linspace(1, 0, f)
        else:
            g = int(1.6 * SR)
            s[-g:] *= np.linspace(1, 0, g)
        segs.append(s)
    wav = os.path.join(TMP, "audio.f32")
    np.concatenate(segs).astype(np.float32).tofile(wav)
    out = os.path.join(OUT, "crate_fx.mp4")
    sh(["ffmpeg", "-v", "error", "-y", "-i", frames_path, "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", wav,
        "-map", "0:v", "-map", "1:a", "-c:v", "libx264", "-crf", "17", "-preset", "slow", "-pix_fmt", "yuv420p",
        "-af", "loudnorm=I=-14:TP=-1.5:LRA=11", "-ac", "2", "-c:a", "aac", "-b:a", "256k", "-ar", "48000",
        "-shortest", "-movflags", "+faststart", out])
    print("wrote", out)


if __name__ == "__main__":
    render(plan())
