#!/usr/bin/env python3
"""
typing_intro.py -- the "prompt typed into CRATE" moment.

AXe taps/typing never reached the app's prompt field on this simulator (taps
land on the rotated laptop layout's wrong coordinates), so the dig itself was
fired through the command channel. This script rebuilds the typing: it takes
the app's REAL rendered prompt line (from a frame after the dig, same font,
same colour, same position modulo the layout shift) and reveals it character
by character over the pre-dig frame, with the app's orange block cursor.
Then the real footage continues from the dig moment.

  python typing_intro.py            -> demo/clips/take1_intro_full.mov (+ _lid.mov, _deck.mov)
"""
import os
import random
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
CLIPS = os.path.abspath(os.path.join(HERE, "..", "..", "demo", "clips"))
SRC = os.path.join(CLIPS, "take1_inner_up.mov")
PRE_T, POST_T, DIG_T = 11.0, 20.0, 12.20
TAIL_END = 27.0                     # real footage used after the dig
PROMPT = "4 bar loop, j dilla laid back drums and a killer nujabes piano sample"
FPS = 30
LEAD, TYPE_DUR, HOLD = 0.35, 3.3, 0.45


def grab(t, path):
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", f"{t}", "-i", SRC, "-frames:v", "1", "-update", "1", path], check=True)
    return np.asarray(Image.open(path).convert("RGB")).copy()


def band(a, y0, y1, x0=100, x1=1600, thr=90):
    sub = a[y0:y1, x0:x1].max(axis=2)
    rows = np.nonzero((sub > thr).sum(axis=1) > 0)[0]
    cols = np.nonzero((sub > thr).sum(axis=0) > 0)[0]
    return y0 + rows.min(), y0 + rows.max(), x0 + cols.min(), x0 + cols.max()


def parse_args():
    """Optional overrides so the same reveal can be reused for later prompts:
    --src take4_inner_up.mov --pre 23.6 --post 27.5 --dig 24.1 --tail 32.5
    --prompt "..." --type-dur 2.0 --out take4_house_full.mov"""
    global SRC, PRE_T, POST_T, DIG_T, TAIL_END, PROMPT, TYPE_DUR, LEAD, HOLD, OUT
    a = sys.argv[1:]
    def opt(name, cast=str, default=None):
        return cast(a[a.index(name) + 1]) if name in a else default
    SRC = os.path.join(CLIPS, opt("--src", str, os.path.basename(SRC)))
    PRE_T = opt("--pre", float, PRE_T); POST_T = opt("--post", float, POST_T); DIG_T = opt("--dig", float, DIG_T)
    TAIL_END = opt("--tail", float, TAIL_END); PROMPT = opt("--prompt", str, PROMPT)
    TYPE_DUR = opt("--type-dur", float, TYPE_DUR); LEAD = opt("--lead", float, LEAD); HOLD = opt("--hold", float, HOLD)
    OUT = opt("--out", str, "take1_intro_full.mov")


def main():
    parse_args()
    tmp = tempfile.mkdtemp(prefix="typing_")
    try:
        pre = grab(PRE_T, os.path.join(tmp, "pre.png"))
        post = grab(POST_T, os.path.join(tmp, "post.png"))
        # orange chevron rows locate the prompt line in each layout
        def chevron(a):
            m = (a[:, :, 0] > 200) & (a[:, :, 1] > 50) & (a[:, :, 1] < 140) & (a[:, :, 2] < 90)
            ys, xs = np.nonzero(m[1000:1300, :100])
            ys = np.unique(ys)
            run = [ys[0]]
            for y in ys[1:]:
                if y - run[-1] > 3:
                    break
                run.append(y)
            return 1000 + run[0], 1000 + run[-1]
        pc0, pc1 = chevron(pre)
        qc0, qc1 = chevron(post)
        dy = pc0 - qc0
        # text band of the real prompt (post) and of the placeholder (pre)
        ty0, ty1, tx0, tx1 = band(post, qc0 - 12, qc1 + 12, x1=1990)
        py0, py1, px0, px1 = band(pre, pc0 - 12, pc1 + 12, x1=1990)
        adv = (tx1 - tx0 + 1) / (len(PROMPT) - 0.15)
        print(f"chevron pre {pc0}-{pc1} post {qc0}-{qc1} dy={dy}; text x {tx0}-{tx1} adv {adv:.2f}; placeholder x {px0}-{px1}")
        orange = post[qc0:qc1 + 1, :100][((post[qc0:qc1 + 1, :100, 0] > 200) & (post[qc0:qc1 + 1, :100, 2] < 90))].mean(axis=0)

        line_y0, line_y1 = min(ty0 + dy, py0) - 6, max(ty1 + dy, py1) + 8
        base = pre.copy()
        base[line_y0:line_y1, tx0 - 6:1990] = 0          # clear the idle placeholder + its cursor
        strip = post[ty0 - 6 + 0:ty1 + 8, :, :]          # real rendered prompt glyphs
        sy0 = ty0 - 6 + dy

        # per-character reveal times (fast, human-ish jitter)
        random.seed(7)
        gaps = [random.uniform(0.7, 1.3) * (1.6 if c == " " else 1.0) for c in PROMPT]
        s = sum(gaps)
        times, acc = [], LEAD
        for g in gaps:
            acc += g / s * TYPE_DUR
            times.append(acc)
        total = LEAD + TYPE_DUR + HOLD
        n = round(total * FPS)
        cur_w = max(6, int(adv * 0.5))
        for i in range(n):
            t = i / FPS
            k = sum(1 for tt in times if tt <= t)
            fr = base.copy()
            xr = int(round(tx0 + k * adv)) if k else tx0
            if k:
                fr[sy0:sy0 + strip.shape[0], tx0 - 2:xr] = strip[:, tx0 - 2:xr]
            typing = k < len(PROMPT)
            blink_on = typing or (int((t - times[-1]) * 2) % 2 == 0)
            if blink_on:
                cy0, cy1 = ty0 + dy - 2, ty1 + dy + 3
                fr[cy0:cy1, xr + 2:xr + 2 + cur_w] = orange.astype(np.uint8)
            Image.fromarray(fr).save(os.path.join(tmp, f"f_{i:04d}.png"))
        typed = os.path.join(tmp, "typed.mov")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-framerate", str(FPS), "-i", os.path.join(tmp, "f_%04d.png"),
                        "-f", "lavfi", "-t", f"{n / FPS:.6f}", "-i", "anullsrc=r=48000:cl=stereo",
                        "-c:v", "libx264", "-preset", "veryfast", "-crf", "14", "-pix_fmt", "yuv420p",
                        "-c:a", "pcm_s16le", "-shortest", typed], check=True)
        full = os.path.join(CLIPS, OUT)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", typed, "-ss", f"{DIG_T}", "-t", f"{TAIL_END - DIG_T}", "-i", SRC,
                        "-filter_complex", "[0:v][0:a][1:v][1:a]concat=n=2:v=1:a=1[v][a]", "-map", "[v]", "-map", "[a]",
                        "-r", str(FPS), "-c:v", "libx264", "-preset", "veryfast", "-crf", "14", "-pix_fmt", "yuv420p",
                        "-c:a", "pcm_s16le", full], check=True)
        print("wrote", full, "typing part", n / FPS, "s; dig at", round(n / FPS, 3))
        open(os.path.splitext(full)[0] + ".txt", "w").write(f"typing_dur={n / FPS:.4f}\ndig_src_t={DIG_T}\n")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
