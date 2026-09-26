#!/usr/bin/env python3
"""
frames_sheet.py -- one-row contact sheet of key moments of a rendered film.

  python frames_sheet.py demo/crate_demo_v1.mp4 demo/crate_demo_v1_frames.jpg id[+offset] ...

Each argument after the output path is a shot id from <film>_timeline.csv
plus an optional offset in seconds into that shot (default: mid-shot).
"""
import csv
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vidcommon as vc


def main():
    film, out, picks = sys.argv[1], sys.argv[2], sys.argv[3:]
    rows = {r["id"]: r for r in csv.DictReader(open(os.path.splitext(film)[0] + "_timeline.csv"))}
    tmp = tempfile.mkdtemp()
    tiles = []
    for p in picks:
        sid, _, off = p.partition("+")
        r = rows[sid]
        t = float(r["start"]) + (float(off) if off else float(r["dur"]) / 2)
        f = os.path.join(tmp, f"{len(tiles)}.png")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", f"{t:.3f}", "-i", film, "-frames:v", "1", "-update", "1",
                        "-vf", "scale=480:270", f], check=True)
        tiles.append((Image.open(f).convert("RGB"), f"{t:5.1f}s  {sid}"))
    pad, lab = 8, 26
    W = len(tiles) * 480 + (len(tiles) + 1) * pad
    H = 270 + 2 * pad + lab
    sheet = Image.new("RGB", (W, H), (255, 255, 255))
    d = ImageDraw.Draw(sheet)
    font = vc.sans_font(18)
    for i, (im, label) in enumerate(tiles):
        x = pad + i * (480 + pad)
        sheet.paste(im, (x, pad))
        d.text((x + 4, pad + 270 + 4), label, font=font, fill=(40, 40, 40))
    sheet.save(out, quality=88)
    print("wrote", out)


if __name__ == "__main__":
    main()
