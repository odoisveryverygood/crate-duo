#!/usr/bin/env python3
"""
jitter_check.py -- measure camera shake: pushes a synthetic frame with small
Gaussian dots through a camera move (old kenburns_filter vs new
camera_filter), tracks each dot's sub-pixel centroid per output frame and
compares it with the analytic, perfectly smooth trajectory.

  python jitter_check.py        -> prints max/rms deviation (px @1080p) + jerk
"""
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vidcommon as vc

KEYS = [{"t": 0, "zoom": 1.0, "cx": 0.5, "cy": 0.5}, {"t": 3.0, "zoom": 1.35, "cx": 0.55, "cy": 0.47}]
DOTS = [(0.40, 0.40), (0.60, 0.55), (0.52, 0.47)]
N = 90


def make_src(path, W, H):
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    img = np.zeros((H, W), np.float32)
    for u, v in DOTS:
        img += np.exp(-(((xx - u * W) ** 2 + (yy - v * H) ** 2) / (2 * (W / 640) ** 2)))
    Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).convert("RGB").save(path)


def expected(t, u, v, W=1920, H=1080):
    def ev(field):
        k0, k1 = KEYS
        p = min(max((t - k0["t"]) / (k1["t"] - k0["t"]), 0), 1)
        s = p * p * (3 - 2 * p)
        return k0[field] + (k1[field] - k0[field]) * s
    z, cx, cy = ev("zoom"), ev("cx"), ev("cy")
    ww, wh = 1 / z, 1 / z
    x0 = min(max(cx - ww / 2, 0), 1 - ww)
    y0 = min(max(cy - wh / 2, 0), 1 - wh)
    return (u - x0) / ww * W, (v - y0) / wh * H


def track(frames_raw, W=1920, H=1080):
    a = np.frombuffer(frames_raw, np.uint8).reshape(-1, H, W).astype(np.float32)
    out = []
    for f in a:
        pts = []
        for u, v in DOTS:
            pass
        out.append(f)
    return a


def run(vf, src):
    r = subprocess.run(["ffmpeg", "-v", "error", "-loop", "1", "-framerate", "30", "-t", f"{N / 30:.4f}", "-i", src,
                        "-vf", vf + ",format=gray", "-frames:v", str(N), "-f", "rawvideo", "-"], capture_output=True)
    if r.returncode:
        print(r.stderr.decode()[-2000:])
        raise SystemExit(1)
    return np.frombuffer(r.stdout, np.uint8).reshape(-1, 1080, 1920).astype(np.float32)


def centroids(frames):
    res = []
    for i, f in enumerate(frames):
        t = i / 30
        row = []
        for u, v in DOTS:
            ex, ey = expected(t, u, v)
            x0, y0 = int(ex) - 12, int(ey) - 12
            win = f[y0:y0 + 25, x0:x0 + 25]
            win = np.clip(win - 20, 0, None)
            yy, xx = np.mgrid[0:25, 0:25]
            s = win.sum() + 1e-6
            row.append((x0 + (win * xx).sum() / s, y0 + (win * yy).sum() / s, ex, ey))
        res.append(row)
    return np.array(res)


def report(name, c):
    dev = np.hypot(c[..., 0] - c[..., 2], c[..., 1] - c[..., 3])
    # jerk: 2nd difference of the measured path minus that of the ideal path
    d2 = np.diff(c[..., :2] - c[..., 2:], n=2, axis=0)
    jerk = np.hypot(d2[..., 0], d2[..., 1])
    vx = np.diff(c[..., 0], axis=0)
    mono = all(((vx[:, j] >= -0.05).all() or (vx[:, j] <= 0.05).all()) for j in range(len(DOTS)))
    print(f"{name:10s} deviation max {dev.max():.2f}px rms {np.sqrt((dev ** 2).mean()):.2f}px | "
          f"frame-to-frame jerk max {jerk.max():.2f}px rms {np.sqrt((jerk ** 2).mean()):.3f}px | monotonic x: {mono}")


def main():
    tmp = tempfile.mkdtemp()
    src = os.path.join(tmp, "dots.png")
    make_src(src, 3840, 2160)
    old = run(vc.kenburns_filter(KEYS, 1920, 1080), src)
    new = run(vc.camera_filter(KEYS, 1920, 1080, work=2.0), src)
    report("kenburns", centroids(old))
    report("camera", centroids(new))


if __name__ == "__main__":
    main()
