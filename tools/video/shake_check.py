#!/usr/bin/env python3
"""
shake_check.py -- frame-to-frame shake of a rendered film section: phase
correlation between consecutive frames of a central patch; reports the
jerk (2nd difference) of the measured shift. Smooth camera -> ~0.

  python shake_check.py film.mp4 start dur
"""
import subprocess
import sys

import numpy as np


def frames(path, ss, dur, w=960, h=540):
    r = subprocess.run(["ffmpeg", "-v", "error", "-ss", str(ss), "-t", str(dur), "-i", path, "-vf",
                        f"scale={w}:{h},format=gray", "-f", "rawvideo", "-"], capture_output=True)
    return np.frombuffer(r.stdout, np.uint8).reshape(-1, h, w).astype(np.float32)


def shift(a, b):
    A = np.fft.fft2(a * np.hanning(a.shape[0])[:, None] * np.hanning(a.shape[1])[None])
    B = np.fft.fft2(b * np.hanning(b.shape[0])[:, None] * np.hanning(b.shape[1])[None])
    R = A * np.conj(B)
    R /= np.abs(R) + 1e-9
    r = np.fft.ifft2(R).real
    y, x = np.unravel_index(np.argmax(r), r.shape)
    # sub-pixel: parabolic fit
    def sub(c, m, p):
        d = (m - p) / (2 * (m - 2 * c + p) + 1e-9)
        return d
    H, W = r.shape
    dy = sub(r[y, x], r[(y - 1) % H, x], r[(y + 1) % H, x])
    dx = sub(r[y, x], r[y, (x - 1) % W], r[y, (x + 1) % W])
    y = y + dy
    x = x + dx
    if y > H / 2: y -= H
    if x > W / 2: x -= W
    return x, y


def main():
    path, ss, dur = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
    f = frames(path, ss, dur)
    c = f[:, 170:370, 330:630]
    s = np.array([shift(c[i], c[i + 1]) for i in range(len(c) - 1)])
    j = np.diff(s, axis=0)
    print(f"{path.split('/')[-1]} {ss}+{dur}: shift/frame max {np.abs(s).max():.2f}px  "
          f"jerk max {np.abs(j).max():.2f}px rms {np.sqrt((j ** 2).mean()):.3f}px (at 960x540)")


if __name__ == "__main__":
    main()
