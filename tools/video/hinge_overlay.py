#!/usr/bin/env python3
"""
hinge_overlay.py -- a small side-view hinge diagram (deck + lid + orange angle
arc + serif angle readout) rendered as transparent overlays for the fold shot
and the snap-open shot. The simulated hinge blanks the inner display while it
moves, so the fold on screen is driven through crate://punch (the exact
mapping HingeFX uses: p = (110 - angle) / 85); this diagram shows the angle
that punch value corresponds to.

  python hinge_overlay.py   -> demo/cards/hinge_fold.mov (16.6 s), hinge_snap.mov (3.0 s)
"""
import math
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vidcommon as vc

W, H = 330, 330
PIVOT = (112, 200)
L = 170
FOLD_DUR, SNAP_DUR = 16.6, 3.0
RAMP = 15.0             # take4: p = 0.95 * (t/15)^1.15, t from the fold shot start


def angle_fold(t):
    p = 0.95 * (min(max(t, 0), RAMP) / RAMP) ** 1.15
    return 110 - 85 * p


def frame(theta, alpha=1.0, ss=3):
    img = Image.new("RGBA", (W * ss, H * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    px, py = PIVOT[0] * ss, PIVOT[1] * ss
    ink = vc.INK + (int(255 * alpha),)
    org = vc.ORANGE + (int(255 * alpha),)
    grey = vc.GREY + (int(255 * alpha),)
    lw = 11 * ss
    # deck
    d.line([(px, py), (px + L * ss, py)], fill=ink, width=lw)
    d.ellipse([px + L * ss - lw / 2, py - lw / 2, px + L * ss + lw / 2, py + lw / 2], fill=ink)
    # lid
    ex = px + L * ss * math.cos(math.radians(theta))
    ey = py - L * ss * math.sin(math.radians(theta))
    d.line([(px, py), (ex, ey)], fill=ink, width=lw)
    d.ellipse([ex - lw / 2, ey - lw / 2, ex + lw / 2, ey + lw / 2], fill=ink)
    d.ellipse([px - lw / 2, py - lw / 2, px + lw / 2, py + lw / 2], fill=ink)
    # arc
    r = 62 * ss
    d.arc([px - r, py - r, px + r, py + r], start=-theta, end=0, fill=org, width=5 * ss)
    # readout: fixed caption under the deck ("hinge 110°"), never collides with the lid
    cf = vc.sans_font(22 * ss)
    f = vc.serif_font(44 * ss, "Regular")
    cap = "hinge"
    cx0, cy0 = px - 6 * ss, py + 34 * ss
    d.text((cx0, cy0 + 14 * ss), cap, font=cf, fill=grey)
    d.text((cx0 + d.textlength(cap, font=cf) + 14 * ss, cy0), f"{theta:.0f}°", font=f, fill=ink)
    return img.resize((W, H), Image.LANCZOS)


def write(frames_fn, n, out):
    tmp = tempfile.mkdtemp(prefix="hinge_")
    try:
        for i in range(n):
            frames_fn(i).save(os.path.join(tmp, f"f_{i:04d}.png"))
        vc.sh(["ffmpeg", "-v", "error", "-y", "-framerate", str(vc.FPS), "-i", os.path.join(tmp, "f_%04d.png"),
               "-c:v", "qtrle", "-pix_fmt", "argb", out])
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print("wrote", out)


def main():
    fps = vc.FPS
    nf = round(FOLD_DUR * fps)
    write(lambda i: frame(angle_fold(i / fps), alpha=min(1.0, i / 12)), nf, os.path.join(vc.CARDS_DIR, "hinge_fold.mov"))
    closed = angle_fold(FOLD_DUR)

    def snap(i):
        t = i / fps
        th = closed + (110 - closed) * min(1.0, t / 0.2) ** 0.6
        a = 1.0 if t < 1.6 else max(0.0, 1 - (t - 1.6) / 0.8)
        return frame(th, alpha=a)
    write(snap, round(SNAP_DUR * fps), os.path.join(vc.CARDS_DIR, "hinge_snap.mov"))


if __name__ == "__main__":
    main()
