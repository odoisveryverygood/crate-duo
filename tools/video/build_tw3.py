#!/usr/bin/env python3
"""build_tw3.py -- ~30 s square brat cut: hook on the hinge drop, orange/white background
alternating per shot (Bitrig's white backdrop keyed to the shot colour, shadows kept as
multiplied shadows), blurry lowercase Arial Narrow captions, the app's own audio.

  ~/vlogcut/.venv/bin/python3 tools/video/build_tw3.py   -> demo/twitter/v3/crate_brat_30.mp4
"""
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage

DL = os.path.expanduser("~/Downloads")
OUT = os.path.expanduser("~/crate-build/demo/twitter/v3")
TMP = os.path.join(OUT, "tmp")
os.makedirs(TMP, exist_ok=True)
S, FPS = 1080, 30
Z, FOLD, BOOK = (os.path.join(DL, n) for n in ("7.mp4", "6.mp4", "crate twitter 2.mp4"))
ORANGE, WHITE = np.array([255, 83, 0], np.float32), np.array([255, 255, 255], np.float32)
NARROW = "/System/Library/Fonts/Supplemental/Arial Narrow.ttf"
DEV_W, DEV_Y = 900, 190          # footage is shrunk into the lower part of the frame, caption above


def sh(cmd, **kw):
    r = subprocess.run(cmd, capture_output=True, **kw)
    if r.returncode:
        print(" ".join(map(str, cmd))[:300]); print(r.stderr.decode()[-1200:]); sys.exit(1)
    return r


# ---------------------------------------------------------------- text
def brat_text(lines, size, color, blur=2.0, align="left", box=(S, S), xy=(64, 64)):
    """RGBA layer with brat-style text (lowercase Arial Narrow, softened)."""
    im = Image.new("RGBA", box, (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(NARROW, size)
    x, y = xy
    for ln in lines:
        w = d.textlength(ln, font=f)
        xx = (box[0] - w) / 2 if align == "center" else x
        d.text((xx, y), ln, font=f, fill=tuple(int(c) for c in color) + (255,))
        y += int(size * 1.0)
    return im.filter(ImageFilter.GaussianBlur(blur)) if blur else im


def card(lines, bg, size=260, sub=None):
    base = Image.new("RGBA", (S, S), tuple(int(c) for c in bg) + (255,))
    fg = WHITE if bg is ORANGE else ORANGE
    n = len(lines)
    y0 = (S - int(size * n)) // 2 - (60 if sub else 0)
    base.alpha_composite(brat_text(lines, size, fg, blur=3.0, align="center", xy=(0, y0)))
    if sub:
        base.alpha_composite(brat_text(sub, 60, fg, blur=0.6, align="center", xy=(0, S - 90 - 66 * len(sub))))
    return np.asarray(base.convert("RGB"))


# ---------------------------------------------------------------- keying
def masks(frame):
    """(backdrop mask, stray mask, device bbox) for one frame."""
    f = frame.astype(np.float32)
    mn, mx, mean = f.min(-1), f.max(-1), f.mean(-1)
    cand = ((mx - mn) < 14) & (mean >= 150)
    lab, _ = ndimage.label(cand)
    edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    region = np.isin(lab, edge[edge > 0])
    dev = ~region
    dl, dn = ndimage.label(dev)
    stray = np.zeros_like(region)
    bbox = None
    if dn:
        sizes = ndimage.sum(dev, dl, range(1, dn + 1))
        keep = int(np.argmax(sizes)) + 1
        stray = dev & (dl != keep)
        ys, xs = np.nonzero(dl == keep)
        bbox = (xs.min(), ys.min(), xs.max(), ys.max())
    return region, stray, bbox, mean


def key(frame, bg):
    """Replace Bitrig's white backdrop with `bg`: its grey shadows become multiplied shadows,
    stray UI (the "iPhone" label, the cursor) is painted out."""
    region, stray, _, mean = masks(frame)
    keepdev = ~region & ~stray
    stray = ndimage.binary_dilation(stray, iterations=3) & ~keepdev
    edge = np.zeros_like(region); edge[-int(region.shape[0] * 0.03):] = True; edge[:int(region.shape[0] * 0.02)] = True
    edge &= ~keepdev
    stray |= edge
    region |= edge
    f = frame.astype(np.float32)
    shade = np.where(stray, 1.0, np.clip(mean / 252.0, 0, 1))[..., None]
    soft = ndimage.gaussian_filter((region | stray).astype(np.float32), 0.8)[..., None]
    out = f * (1 - soft) + (bg * shade) * soft
    return np.clip(out, 0, 255).astype(np.uint8)


def crop_for(frame, margin=0.10):
    """Square crop centred on the device in `frame` (fixed for the whole shot)."""
    _, _, bb, _ = masks(frame)
    h, w, _ = frame.shape
    if bb is None:
        return (0, 0, w)
    x0, y0, x1, y1 = bb
    side = int(max(x1 - x0, y1 - y0) * (1 + 2 * margin))
    side = min(side, w, h)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    x = int(min(max(0, cx - side / 2), w - side)); y = int(min(max(0, cy - side / 2), h - side))
    return (x, y, side)


def compose(frame, bg, crop, lines):
    """Keyed footage, framed on the device, placed under the caption on the bg colour."""
    x, y, side = crop
    k = key(frame[y:y + side, x:x + side], bg)
    top = 170 if lines <= 1 else 270
    box = min(S - 60, S - top - 30)
    im = Image.fromarray(k).resize((box, box), Image.LANCZOS)
    canvas = Image.new("RGB", (S, S), tuple(int(c) for c in bg))
    canvas.paste(im, ((S - box) // 2, top))
    return canvas


# ---------------------------------------------------------------- shots
def render_shot(i, s):
    vpath, apath = os.path.join(TMP, f"v{i:02d}.mov"), os.path.join(TMP, f"a{i:02d}.wav")
    bg = s["bg"]
    fg = WHITE if bg is ORANGE else ORANGE
    speed = s.get("speed", 1.0)
    dur = s["dur"] if "card" in s else round(s["src_dur"] / speed, 3)
    n = round(dur * FPS)
    enc = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{S}x{S}",
                            "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-crf", "15", "-preset", "fast",
                            "-pix_fmt", "yuv420p", vpath], stdin=subprocess.PIPE)
    if "card" in s:
        fr = s["card"].tobytes()
        for _ in range(n):
            enc.stdin.write(fr)
    else:
        cap = brat_text(s["cap"], 118, fg, blur=1.6, xy=(58, 34)) if s.get("cap") else None
        dec = subprocess.Popen(["ffmpeg", "-v", "error", "-ss", str(s["start"]), "-t", str(s["src_dur"]), "-i", s["src"],
                                "-vf", f"setpts=(PTS-STARTPTS)/{speed},fps={FPS},scale={S}:{S}:flags=lanczos",
                                "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
        got, crop = 0, None
        while got < n:
            buf = dec.stdout.read(S * S * 3)
            if len(buf) < S * S * 3:
                break
            fr = np.frombuffer(buf, np.uint8).reshape(S, S, 3)
            if crop is None:
                crop = s.get("crop") or crop_for(fr, s.get("margin", 0.10))
            im = compose(fr, bg, crop, len(s.get("cap") or [])).convert("RGBA")
            if cap:
                im.alpha_composite(cap)
            enc.stdin.write(im.convert("RGB").tobytes()); got += 1
            last = im
        while got < n:                      # pad a short source with its last frame
            enc.stdin.write(last.convert("RGB").tobytes()); got += 1
        dec.stdout.close(); dec.wait()
    enc.stdin.close(); enc.wait()
    # audio
    a = s.get("a")
    if a is None and "card" not in s and speed == 1.0:
        a = (s["src"], s["start"])
    if a:
        sh(["ffmpeg", "-v", "error", "-y", "-ss", str(a[1]), "-t", str(dur), "-i", a[0], "-vn",
            "-af", f"aresample=48000,aformat=channel_layouts=stereo,apad,atrim=0:{dur},afade=t=in:d=0.01,afade=t=out:st={max(0, dur-0.02):.3f}:d=0.02",
            "-ar", "48000", apath])
    else:
        sh(["ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-t", str(dur), "-i", "anullsrc=r=48000:cl=stereo", apath])
    print(f"  {i:02d} {dur:5.2f}s {s.get('label', '')}")
    return vpath, apath, dur


def shots():
    O, W = ORANGE, WHITE
    return [
        dict(label="fold build", src=FOLD, start=5.6, src_dur=2.8, bg=O, cap=["fold it."]),
        dict(label="snap drop", src=FOLD, start=8.4, src_dur=2.6, bg=W, cap=["drop it."]),
        dict(label="title", card=card(["crate."], O, 300), dur=0.9, bg=O, a=(FOLD, 11.0)),
        dict(label="typing", src=Z, start=1.5, src_dur=3.8, speed=3.5, bg=W, cap=["type a vibe."]),
        dict(label="jazz drop", src=Z, start=5.3, src_dur=3.2, bg=O, cap=["get a beat."]),
        dict(label="seq by hand", src=Z, start=37.4, src_dur=3.0, bg=W, cap=["or play it."]),
        dict(label="chop", src=Z, start=45.2, src_dur=2.6, bg=O, cap=["chop it."]),
        dict(label="house typing", src=Z, start=70.0, src_dur=4.4, speed=4.0, bg=W, cap=["house?"], a=(Z, 47.8)),
        dict(label="house drop", src=Z, start=74.4, src_dur=3.0, bg=W, cap=["house."]),
        dict(label="back screen", src=Z, start=107.4, src_dur=3.0, bg=O, cap=["back screen", "= crowd."]),
        dict(label="close it", src=BOOK, start=1.1, src_dur=4.0, bg=W, cap=["close it.", "keep playing."]),
        dict(label="end", card=card(["crate."], O, 300, sub=["your ai foldable sampler.", "crateduo.vercel.app"]),
             dur=2.8, bg=O, a=(BOOK, 5.1)),
    ]


if __name__ == "__main__":
    parts = [render_shot(i, s) for i, s in enumerate(shots())]
    vl, al = os.path.join(TMP, "v.txt"), os.path.join(TMP, "a.txt")
    open(vl, "w").write("".join(f"file '{v}'\n" for v, _, _ in parts))
    open(al, "w").write("".join(f"file '{a}'\n" for _, a, _ in parts))
    out = os.path.join(OUT, "crate_brat_30.mp4")
    sh(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", vl, "-f", "concat", "-safe", "0", "-i", al,
        "-map", "0:v", "-map", "1:a", "-c:v", "libx264", "-crf", "17", "-preset", "slow", "-pix_fmt", "yuv420p",
        "-af", "loudnorm=I=-14:TP=-1.5:LRA=11", "-c:a", "aac", "-b:a", "256k", "-movflags", "+faststart", out])
    print("wrote", out, f"{sum(d for _, _, d in parts):.1f}s")
