#!/usr/bin/env python3
"""build_twitter.py -- ~30 s X/Twitter cut: french jazz prompt -> beat -> GPT -> finger drums,
hard cut to an empty crate -> deep house -> hinge fold build -> snap DROP -> back screen -> perform -> end card.
Captions burned in (X autoplays muted). Audio = the app's own master bus from each take.

  ~/vlogcut/.venv/bin/python3 tools/video/build_twitter.py   -> demo/twitter/crate_twitter.mp4
"""
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import vidcommon as vc

DEMO = os.path.abspath(os.path.join(HERE, "..", "..", "demo"))
OUT_DIR = os.path.join(DEMO, "twitter")
CAP_DIR = os.path.join(DEMO, "cards", "tw")
os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(CAP_DIR, exist_ok=True)

J, H = "clips/twjazz_inner_up.mov", "clips/twhouse_inner_up.mov"
JA, HA = "clips/twjazz_app_aligned.wav", "clips/twhouse_app_aligned.wav"
BAR_H = 4 * 60 / 124.0
LAPTOP = {"pose": "laptop", "view": "front", "az": 9}
LAPTOP_DECK = {"pose": "laptop", "view": "front", "el": 38}
SCREENS = {"lid": {"crop": "lid"}, "deck": {"crop": "deck"}}


def k(t, zoom, cx=0.5, cy=0.5):
    return {"t": t, "zoom": zoom, "cx": cx, "cy": cy}


def ks(t, zoom, screen, u, v):
    return {"t": t, "zoom": zoom, "screen": screen, "u": u, "v": v}


def caption(name, text, sub=None):
    """Bottom-centre pill: white semibold on ink, optional grey second line."""
    W, Hh = vc.CANVAS_W, vc.CANVAS_H
    img = Image.new("RGBA", (W, Hh), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    f1 = vc.sans_font(46, bold=True)
    f2 = vc.sans_font(30)
    w1 = d.textlength(text, font=f1)
    w2 = d.textlength(sub, font=f2) if sub else 0
    bw = max(w1, w2) + 72
    bh = 92 + (48 if sub else 0)
    x0, y0 = (W - bw) / 2, Hh - bh - 64
    d.rounded_rectangle((x0, y0, x0 + bw, y0 + bh), radius=26, fill=(20, 19, 17, 235))
    d.text(((W - w1) / 2, y0 + 20), text, font=f1, fill=(255, 255, 255, 255))
    if sub:
        d.text(((W - w2) / 2, y0 + 20 + 58), sub, font=f2, fill=(190, 184, 176, 255))
    p = os.path.join(CAP_DIR, name + ".png")
    img.save(p)
    return os.path.relpath(p, DEMO)


def end_card():
    W, Hh = vc.CANVAS_W, vc.CANVAS_H
    img = Image.new("RGB", (W, Hh), vc.CREAM)
    d = ImageDraw.Draw(img)
    t = "CRATE"
    f = vc.serif_font(190, "Regular")
    d.text(((W - d.textlength(t, font=f)) / 2, 300), t, font=f, fill=vc.INK)
    for i, (line, size, col) in enumerate([
            ("The AI sampler for iPhone Duo.", 52, vc.INK),
            ("Type a vibe. Get a beat. Fold to drop it.", 40, vc.GREY),
            ("1st place · YC × Bitrig iPhone Duo hackathon", 34, (234, 88, 12))]):
        ff = vc.sans_font(size, bold=(i == 0))
        d.text(((W - d.textlength(line, font=ff)) / 2, 560 + i * 80), line, font=ff, fill=col)
    p = os.path.join(CAP_DIR, "end.png")
    img.save(p)
    return os.path.relpath(p, DEMO)


def fold_keys(ss, dur):
    """Hinge angle per the take's recorded FX amount (110° rest -> ~40° at full), relative to the shot start."""
    d = json.load(open(os.path.join(DEMO, "clips", "twhouse_timing.json")))
    v0 = d["t_v0_inner"]
    pts = [(e["t"] - v0, float(e["q"].split("=")[1])) for e in d["events"]
           if e.get("cmd") == "fxamt" and e.get("q", "").startswith("v=")]
    keys, last = [{"t": 0.0, "deg": 110.0}], -1.0
    for t, v in pts:
        if ss < t < ss + dur - 0.05 and t - last >= 0.3 and v > 0:
            keys.append({"t": round(t - ss, 2), "deg": round(110 - 70 * v, 1)})
            last = t
    keys.append({"t": dur, "deg": keys[-1]["deg"]})
    return keys


def drop_time():
    d = json.load(open(os.path.join(DEMO, "clips", "twhouse_timing.json")))
    v0 = d["t_v0_inner"]
    return min(e["t"] - v0 for e in d["events"] if e.get("event") == "drop" or e.get("name") == "drop")


def build():
    drop = drop_time()                                   # ~34.5 s into the house take
    build_ss = round(drop - 2 * BAR_H, 3)                # last 2 bars of the 4-bar build
    dig_ss = 12.4
    dig_dur = round(build_ss - 7 * BAR_H - dig_ss, 3)    # whole-bar jump keeps the groove in phase
    fk = fold_keys(build_ss, round(2 * BAR_H, 3))
    end_deg = fk[-1]["deg"]

    shots = [
        # --- french jazz
        {"type": "device", "id": "j_prompt", "device": LAPTOP, "clip": J, "ss": 12.4, "dur": 3.4,
         "keys": [k(0, 1.22, 0.5, 0.47), k(3.4, 1.32, 0.5, 0.45)],
         "overlay": {"path": caption("c1", "I typed “french jazz piano sample”", "into my iPhone Duo")}},
        {"type": "clip", "id": "j_gpt", "clip": J, "ss": 15.8, "dur": 3.8,
         "keys": [k(0, 1.25, 0.45, 0.3), k(3.8, 1.55, 0.35, 0.36)],
         "overlay": {"path": caption("c2", "Beat in 0.3 s from my own samples", "then GPT arranges it while it plays")}},
        {"type": "device", "id": "j_drums", "device": LAPTOP_DECK, "clip": J, "ss": 19.6, "dur": 3.0,
         "keys": [ks(0, 2.0, "deck", 0.43, 0.6), ks(3.0, 2.2, "deck", 0.45, 0.62)],
         "overlay": {"path": caption("c3", "Then you play it")}},
        # --- deep house
        {"type": "clip", "id": "h_dig", "clip": H, "ss": dig_ss, "dur": dig_dur,
         "keys": [k(0, 1.0), k(dig_dur, 1.06)],
         "overlay": {"path": caption("c4", "“deep house, 124”")}},
        {"type": "device_anim", "id": "h_fold", "device": LAPTOP, "clip": H, "ss": build_ss, "dur": round(2 * BAR_H, 3),
         "open_keys": fk, "keys": [k(0, 1.2, 0.5, 0.5), k(round(2 * BAR_H, 3), 1.36, 0.5, 0.52)], "screens": SCREENS,
         "overlay": {"path": caption("c5", "The hinge is the FX knob", "fold it to build")}},
        {"type": "device_anim", "id": "h_snap", "device": LAPTOP, "clip": H, "ss": round(drop, 3), "dur": 2.4,
         "open_keys": [{"t": 0, "deg": end_deg}, {"t": 0.14, "deg": 110}, {"t": 2.4, "deg": 110}],
         "keys": [k(0, 1.36, 0.5, 0.52), k(2.4, 1.2, 0.5, 0.5)], "screens": SCREENS,
         "overlay": {"path": caption("c6", "Snap it open → DROP")}},
        {"type": "clip", "id": "h_back", "clip": "clips/dropback_outer_up.mov", "ss": 5.6, "dur": 2.4,
         "keys": [k(0, 1.12, 0.5, 0.45), k(2.4, 1.2, 0.5, 0.45)],
         "overlay": {"path": caption("c7", "The back screen is for the crowd")}},
        {"type": "clip", "id": "h_perform", "clip": H, "ss": round(drop + 4.8, 3), "dur": 3.2,
         "keys": [k(0, 1.3, 0.5, 0.28), k(3.2, 1.45, 0.5, 0.28)],
         "overlay": {"path": caption("c8", "AI PERFORM plays fills with you")}},
        {"type": "image", "id": "end", "path": end_card(), "dur": 3.4, "keys": [k(0, 1.0), k(3.4, 1.03)]},
    ]
    t, st = 0.0, {}
    for s in shots:
        s.setdefault("audio", "silent")
        st[s["id"]] = t
        t += s["dur"]
    jazz_len = st["h_dig"]
    music = [
        {"file": JA, "at": 0.0, "track_in": 12.4, "dur": round(jazz_len, 3), "gain_db": -2.0, "fade_in": 0.0, "fade_out": 0.04},
        {"file": HA, "at": st["h_dig"], "track_in": dig_ss, "dur": dig_dur, "gain_db": -2.0, "fade_in": 0.02, "fade_out": 0.03},
        {"file": HA, "at": st["h_fold"], "track_in": build_ss, "dur": round(t - st["h_fold"], 3),
         "gain_db": -2.0, "fade_in": 0.03, "fade_out": 1.6},
    ]
    cfg = {"w": 1920, "h": 1080, "fps": 30, "shots": shots, "music": music, "_total_estimate": round(t, 3)}
    out = os.path.join(OUT_DIR, "crate_twitter_shotlist.json")
    json.dump(cfg, open(out, "w"), indent=1)
    print("wrote", out, f"(~{t:.1f}s)", "dig_dur", dig_dur, "build_ss", build_ss, "drop", round(drop, 2))
    return out


if __name__ == "__main__":
    js = build()
    subprocess.run([sys.executable, os.path.join(HERE, "assemble.py"), js, "--out",
                    os.path.join(OUT_DIR, "crate_twitter.mp4")], check=True, cwd=DEMO)
