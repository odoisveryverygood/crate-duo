#!/usr/bin/env python3
"""build_tw2.py -- two square X cuts of CRATE from the Bitrig screen recordings in ~/Downloads.

  ~/vlogcut/.venv/bin/python3 tools/video/build_tw2.py brat   -> demo/twitter/v2/crate_brat.mp4
  ~/vlogcut/.venv/bin/python3 tools/video/build_tw2.py clean  -> demo/twitter/v2/crate_clean.mp4

A shot is a footage clip (src, start, src_dur, speed) or a card (png), plus an audio source.
Footage at speed 1 keeps its own sound; sped-up typing and cards take audio from `a` (an L-cut
from the neighbouring shot) so the beat never drops out.
"""
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

DL = os.path.expanduser("~/Downloads")
OUT = os.path.expanduser("~/crate-build/demo/twitter/v2")
TMP = os.path.join(OUT, "tmp")
os.makedirs(TMP, exist_ok=True)
S = 1080
FPS = 30
Z = os.path.join(DL, "7.mp4")                    # the long take with auto-zoom
FOLD = os.path.join(DL, "6.mp4")                 # laptop pose: fold build + snap DROP
BOOK = os.path.join(DL, "crate twitter 2.mp4")   # book -> closed -> outer-screen pads
ORANGE = (255, 83, 0)
ARIAL = "/System/Library/Fonts/Supplemental/Arial.ttf"
HNEUE = "/System/Library/Fonts/HelveticaNeue.ttc"


def sh(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode:
        print(" ".join(cmd)[:400]); print(r.stderr[-1500:]); sys.exit(1)


# ------------------------------------------------------------------ graphics
def brat_card(name, lines, sub=None, right=None):
    """Full-frame orange card, white lowercase Arial, left aligned (the user's style)."""
    im = Image.new("RGB", (S, S), ORANGE)
    d = ImageDraw.Draw(im)
    size = 190 if max(len(l) for l in lines) <= 8 else 150 if max(len(l) for l in lines) <= 12 else 118
    f = ImageFont.truetype(ARIAL, size)
    lh = int(size * 1.02)
    y = (S - lh * len(lines)) // 2 - (40 if sub else 0) - (lh // 2 if right else 0)
    for l in lines:
        d.text((64, y), l, font=f, fill="white"); y += lh
    if right:
        fr = ImageFont.truetype(ARIAL, 130)
        w = d.textlength(right, font=fr)
        y_last = y - lh
        d.text((S - 64 - w, y_last + lh), right, font=fr, fill="white")
    if sub:
        fs = ImageFont.truetype(ARIAL, 40)
        yy = S - 64 - 48 * len(sub)
        for s in sub:
            d.text((64, yy), s, font=fs, fill="white"); yy += 48
    p = os.path.join(TMP, name + ".png"); im.save(p); return p


def brat_tag(name, text):
    """Orange sticker with white Arial, top-left, for use over footage."""
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(ARIAL, 64)
    w = d.textlength(text, font=f)
    d.rectangle((40, 40, 40 + w + 44, 40 + 96), fill=ORANGE + (255,))
    d.text((62, 52), text, font=f, fill="white")
    p = os.path.join(TMP, name + ".png"); im.save(p); return p


def clean_caption(name, text):
    """Top-centre white pill with a soft edge, black Helvetica Neue Medium."""
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(HNEUE, 50, index=10)  # Helvetica Neue Medium
    w = d.textlength(text, font=f)
    x0, y0 = (S - w) / 2 - 34, 46
    d.rounded_rectangle((x0 + 2, y0 + 4, x0 + w + 70, y0 + 92), radius=46, fill=(0, 0, 0, 40))
    d.rounded_rectangle((x0, y0, x0 + w + 68, y0 + 88), radius=44, fill=(255, 255, 255, 250), outline=(0, 0, 0, 30), width=2)
    d.text((x0 + 34, y0 + 16), text, font=f, fill=(20, 20, 20, 255))
    p = os.path.join(TMP, name + ".png"); im.save(p); return p


def clean_end_card(name):
    """Poster-style end card rendered by Chrome (Doto wordmark + system type), 1080x1080."""
    html = os.path.join(TMP, name + ".html"); png = os.path.join(TMP, name + ".png")
    open(html, "w").write("""<!doctype html><html><head><meta charset="utf-8">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Doto:wght@800&display=swap">
<style>html,body{margin:0;background:#fff}body{width:1080px;height:1080px;display:flex;flex-direction:column;
align-items:center;justify-content:center;font-family:-apple-system,"SF Pro Display","Helvetica Neue",Arial,sans-serif;color:#1d1d1f;text-align:center}
.mark{font:800 120px/1 "Doto",ui-monospace,Menlo,monospace;letter-spacing:.05em;display:flex;align-items:center;gap:26px}
.mark i{width:26px;height:26px;border-radius:50%;background:#fa5b1c;display:block}
h1{margin:44px 0 0;font-size:68px;font-weight:600;letter-spacing:-.03em}
.badge{margin-top:40px;display:inline-flex;align-items:center;gap:14px;padding:16px 30px;border-radius:999px;background:#f5f5f7;font-size:32px;font-weight:600}
.badge i{width:13px;height:13px;border-radius:50%;background:#fa5b1c;display:block}
.url{margin-top:30px;font-size:34px;color:#6e6e73}</style></head><body>
<div class="mark"><i></i>CRATE</div><h1>Your AI foldable sampler.</h1>
<div class="badge"><i></i>1st place · YC × Bitrig iPhone Duo Hackathon</div>
<div class="url">crateduo.vercel.app</div></body></html>""")
    chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    sh([chrome, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--window-size=1080,1080",
        "--virtual-time-budget=4000", f"--screenshot={png}", "file://" + html])
    return png


# ------------------------------------------------------------------ render
def render(shots, out):
    parts = []
    for i, s in enumerate(shots):
        p = os.path.join(TMP, f"{os.path.basename(out)}_{i:02d}.mp4")
        speed = s.get("speed", 1.0)
        dur = s["dur"] if "png" in s else round(s["src_dur"] / speed, 3)
        cmd = ["ffmpeg", "-v", "error", "-y"]
        if "png" in s:
            cmd += ["-loop", "1", "-framerate", str(FPS), "-t", f"{dur}", "-i", s["png"]]
            vf = f"[0:v]scale={S}:{S},format=yuv420p,fps={FPS}[v0]"
        else:
            cmd += ["-ss", f"{s['start']}", "-t", f"{s['src_dur']}", "-i", s["src"]]
            z = s.get("zoom")  # optional slow push: (from, to) scale
            base = f"[0:v]setpts=(PTS-STARTPTS)/{speed},scale={S}:{S}:force_original_aspect_ratio=decrease,pad={S}:{S}:(ow-iw)/2:(oh-ih)/2:white,fps={FPS}"
            if z:
                n = max(1, round(dur * FPS))
                base += (f",scale={S*2}:{S*2},zoompan=z='{z[0]}+({z[1]}-{z[0]})*on/{n}':x='iw/2-(iw/zoom/2)':"
                         f"y='ih/2-(ih/zoom/2)':d=1:s={S}x{S}:fps={FPS}")
            vf = base + ",format=yuv420p[v0]"
        # audio
        a = s.get("a")
        if a is None and "png" not in s and speed == 1.0:
            a = (s["src"], s["start"])
        if a:
            cmd += ["-ss", f"{a[0 + 1]}", "-t", f"{dur}", "-i", a[0]]
            ain = "1:a"
        else:
            cmd += ["-f", "lavfi", "-t", f"{dur}", "-i", "anullsrc=r=48000:cl=stereo"]
            ain = "1:a"
        filt = vf
        vlast = "v0"
        ovs = s.get("ov") or []
        if isinstance(ovs, str):
            ovs = [(ovs, 0, dur)]
        for j, (png, t0, t1) in enumerate(ovs):
            cmd += ["-loop", "1", "-framerate", str(FPS), "-t", f"{dur}", "-i", png]
            nxt = f"v{j + 1}"
            filt += f";[{vlast}][{2 + j}:v]overlay=0:0:format=auto:enable='between(t,{t0},{t1})'[{nxt}]"
            vlast = nxt
        if ovs:
            filt += f";[{vlast}]format=yuv420p[vf]"; vlast = "vf"
        fo = max(0.0, dur - 0.025)
        filt += (f";[{ain}]aresample=48000,aformat=channel_layouts=stereo,apad,atrim=0:{dur},"
                 f"afade=t=in:d=0.012,afade=t=out:st={fo:.3f}:d=0.025[a]")
        cmd += ["-filter_complex", filt, "-map", f"[{vlast}]", "-map", "[a]", "-t", f"{dur}",
                "-c:v", "libx264", "-crf", "14", "-preset", "medium", "-r", str(FPS),
                "-c:a", "pcm_s16le", p.replace(".mp4", ".mov")]
        p = p.replace(".mp4", ".mov")
        sh(cmd)
        parts.append((p, dur))
        print(f"  {i:02d} {dur:5.2f}s {s.get('label', '')}")
    # concat + loudness
    lst = os.path.join(TMP, os.path.basename(out) + ".txt")
    open(lst, "w").write("".join(f"file '{p}'\n" for p, _ in parts))
    sh(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", lst,
        "-af", "loudnorm=I=-14:TP=-1.5:LRA=11", "-c:v", "libx264", "-crf", "17", "-preset", "slow",
        "-pix_fmt", "yuv420p", "-movflags", "+faststart", "-c:a", "aac", "-b:a", "256k", "-ar", "48000", out])
    total = sum(d for _, d in parts)
    print(f"wrote {out}  ({total:.1f}s)")


# ------------------------------------------------------------------ cuts
def brat():
    c = brat_card
    return [
        dict(label="typing hook", src=Z, start=1.5, src_dur=3.8, speed=3.5, ov=brat_tag("t_type", "i typed a vibe")),
        dict(label="jazz drop", src=Z, start=5.3, src_dur=3.7),
        dict(label="card piano", png=c("c_piano", ["hmm...", "piano?"]), dur=1.1, a=(Z, 11.2)),
        dict(label="typing piano", src=Z, start=21.2, src_dur=6.2, speed=3.1, a=(Z, 12.3)),
        dict(label="piano in", src=Z, start=27.8, src_dur=7.2),
        dict(label="card play", png=c("c_play", ["now play", "it yourself"]), dur=1.0, a=(Z, 35.0)),
        dict(label="seq", src=Z, start=37.4, src_dur=3.9, ov=brat_tag("t_seq", "sequencer")),
        dict(label="keys", src=Z, start=42.5, src_dur=1.7, ov=brat_tag("t_keys", "keys")),
        dict(label="chop", src=Z, start=45.1, src_dur=5.4, ov=brat_tag("t_chop", "chop")),
        dict(label="card house", png=c("c_house", ["house?"]), dur=0.9, a=(Z, 50.5)),
        dict(label="typing house", src=Z, start=70.0, src_dur=4.4, speed=4.0),
        dict(label="house drop", src=Z, start=74.4, src_dur=6.6),
        dict(label="card fold", png=c("c_fold", ["fold it."]), dur=0.9, a=(Z, 81.0)),
        dict(label="fold build", src=FOLD, start=3.2, src_dur=5.2, ov=brat_tag("t_build", "build")),
        dict(label="snap drop", src=FOLD, start=8.4, src_dur=3.4, ov=brat_tag("t_drop", "snap → drop")),
        dict(label="back screen", src=Z, start=107.4, src_dur=3.6, ov=brat_tag("t_crowd", "back screen = crowd")),
        dict(label="card close", png=c("c_close", ["close it.", "keep playing."]), dur=1.1, a=(BOOK, 0.0)),
        dict(label="book to closed", src=BOOK, start=1.1, src_dur=7.8),
        dict(label="end card", png=c("c_end", ["your ai", "foldable", "sampler"], right="CRATE",
                                    sub=["1st place · yc × bitrig iphone duo hackathon", "crateduo.vercel.app"]),
             dur=3.0, a=(BOOK, 8.9)),
    ]


def clean():
    k = clean_caption
    return [
        dict(label="cold open fold+drop", src=FOLD, start=4.4, src_dur=7.5,
             ov=[(k("k_fold", "fold to build. snap to drop."), 0, 4.1),
                 (k("k_title", "CRATE · an AI sampler for iPhone Duo"), 4.1, 7.5)]),
        dict(label="typing", src=Z, start=1.5, src_dur=3.8, speed=3.5, ov=k("k_type", "type a vibe")),
        dict(label="jazz drop", src=Z, start=5.3, src_dur=3.7, ov=k("k_beat", "get a beat in 0.3s")),
        dict(label="typing piano", src=Z, start=21.2, src_dur=6.2, speed=3.1, ov=k("k_piano", "“add some french piano”"), a=(Z, 11.2)),
        dict(label="piano in", src=Z, start=27.8, src_dur=6.2),
        dict(label="seq", src=Z, start=37.4, src_dur=3.9, ov=k("k_play", "or play it by hand")),
        dict(label="keys", src=Z, start=42.5, src_dur=1.7, ov=k("k_play2", "or play it by hand")),
        dict(label="chop", src=Z, start=45.1, src_dur=5.0, ov=k("k_chop", "chop the sample")),
        dict(label="typing house", src=Z, start=70.0, src_dur=4.4, speed=4.0, ov=k("k_house", "“some house drums”")),
        dict(label="house drop", src=Z, start=74.4, src_dur=5.0),
        dict(label="back screen", src=Z, start=107.4, src_dur=3.6, ov=k("k_crowd", "the back screen is for the crowd")),
        dict(label="book to closed", src=BOOK, start=0.4, src_dur=8.4, ov=k("k_close", "close it. keep playing.")),
        dict(label="end card", png=clean_end_card("k_end"), dur=3.2, a=(BOOK, 8.8)),
    ]


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "brat"
    shots = brat() if which == "brat" else clean()
    render(shots, os.path.join(OUT, f"crate_{which}.mp4"))
