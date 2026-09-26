#!/usr/bin/env python3
"""
build_v2_test.py -- ~23 s test of the v2 "real iPhone Duo" look, cut from the
v1 footage: title -> laptop-pose device (typing, push on the prompt, pull
back as the pads fill) -> push-in on the JEV readout then the GPT line ->
deck push-in while finger drumming -> three screens (front + back view).

  ~/vlogcut/.venv/bin/python3 tools/video/build_v2_test.py      # json + render
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEMO = os.path.abspath(os.path.join(HERE, "..", "..", "demo"))
BAR = 4 * 60 / 92.0
INTRO_TYPING, INTRO_DIG_SRC = 4.1, 12.2


def k(t, zoom, cx=0.5, cy=0.5, **kw):
    d = {"t": t, "zoom": zoom, "cx": cx, "cy": cy}
    d.update(kw)
    return d


def ks(t, zoom, screen, u, v):
    return {"t": t, "zoom": zoom, "screen": screen, "u": u, "v": v}


LAPTOP = {"pose": "laptop", "view": "front", "az": 9}          # slight 3/4: side walls + hinge end read as hardware
LAPTOP_DECK = {"pose": "laptop", "view": "front", "el": 38}     # higher camera: less deck foreshortening
SHOTS = [
    {"type": "image", "id": "title", "path": "cards/title.png", "dur": 3.0,
     "keys": [k(0, 1.0), k(3.0, 1.04, 0.5, 0.47)]},
    # typing on the lid (camera on the prompt line), Return -> pull back as the pads fill
    {"type": "device", "id": "dev_prompt", "device": LAPTOP, "clip": "clips/take1_intro_full.mov", "ss": 0.5, "dur": 5.2,
     "keys": [ks(0, 1.75, "lid", 0.36, 0.84), ks(3.45, 2.0, "lid", 0.40, 0.84), k(5.0, 1.0), k(5.2, 1.0)]},
    # push in on the JEV readout, then down to the AI log as the GPT line lands
    {"type": "device", "id": "dev_jev", "device": LAPTOP, "clip": "clips/take1_intro_full.mov", "ss": 5.7, "dur": 4.5,
     "keys": [k(0, 1.0), ks(1.3, 2.35, "lid", 0.84, 0.07), ks(2.3, 2.35, "lid", 0.84, 0.07),
              ks(3.2, 2.1, "lid", 0.70, 0.90), ks(4.5, 2.15, "lid", 0.72, 0.90)]},
    # the deck: finger drumming (2 bars later in the same take)
    {"type": "device", "id": "dev_pads", "device": LAPTOP_DECK, "clip": "clips/take1_inner_up.mov", "ss": None, "dur": 4.0,
     "keys": [ks(0, 2.05, "deck", 0.43, 0.55), ks(4.0, 2.3, "deck", 0.45, 0.58)]},
    # three screens: lid + deck from the front, the crowd card on the back of the lid
    {"type": "device", "id": "three_screens", "device": {"pose": "laptop", "view": "front+back", "fill_back": 0.70, "az": 6},
     "clip": "clips/take1_inner_up.mov", "ss": None, "dur": 6.0,
     "screens": {"lid": {"crop": "lid"}, "deck": {"crop": "deck"}, "back_deck": {"crop": "deck"},
                 "back_outer": {"clip": "clips/take3_outer_up.mov", "ss": 0.4, "fit": "letterbox"}},
     "keys": [k(0, 1.0), k(6.0, 1.05, 0.5, 0.49)]},
]


def build():
    t, starts = 0.0, {}
    for s in SHOTS:
        starts[s["id"]] = t
        t += s["dur"]
    total = t
    S = {s["id"]: s for s in SHOTS}
    # take1 clock continuity (whole-bar jumps keep the groove's phase)
    jev_end_take1 = S["dev_jev"]["ss"] + S["dev_jev"]["dur"] - INTRO_TYPING + INTRO_DIG_SRC
    S["dev_pads"]["ss"] = round(jev_end_take1 + 2 * BAR, 3)
    S["three_screens"]["ss"] = round(S["dev_pads"]["ss"] + S["dev_pads"]["dur"] + 6 * BAR, 3)
    for s in SHOTS:
        s.setdefault("audio", "silent")
    gpt_t = starts["dev_jev"] + (INTRO_DIG_SRC + 4.79 + INTRO_TYPING - INTRO_DIG_SRC - S["dev_jev"]["ss"])  # GPT lands
    xf = round(gpt_t - 0.3, 3)
    xf_take1 = S["dev_jev"]["ss"] + (xf - starts["dev_jev"]) - INTRO_TYPING + INTRO_DIG_SRC
    app = "clips/take1_app_aligned.wav"
    music = [
        {"file": "music/horn.wav", "at": 0.0, "track_in": 0.0, "dur": round(xf + 2.4, 3), "gain_db": 8.0,
         "fade_in": 0.3, "fade_out": 2.4, "note": "song under title/prompt/readout"},
        {"file": app, "at": xf, "track_in": round(xf_take1, 3), "dur": round(starts["dev_pads"] - xf + 0.03, 3),
         "gain_db": -3.0, "fade_in": 1.4, "fade_out": 0.03, "note": "CRATE's beat takes over as GPT lands"},
        {"file": app, "at": starts["dev_pads"], "track_in": S["dev_pads"]["ss"], "dur": S["dev_pads"]["dur"] + 0.03,
         "gain_db": -3.0, "fade_in": 0.03, "fade_out": 0.03, "note": "finger drumming (synced)"},
        {"file": app, "at": starts["three_screens"], "track_in": S["three_screens"]["ss"], "dur": S["three_screens"]["dur"],
         "gain_db": -3.0, "fade_in": 0.03, "fade_out": 1.6, "note": "AI PERFORM part"},
    ]
    cfg = {"w": 1920, "h": 1080, "fps": 30, "shots": SHOTS, "music": music, "_total_estimate": round(total, 3)}
    out = os.path.join(DEMO, "crate_demo_v2_test_shotlist.json")
    json.dump(cfg, open(out, "w"), indent=1)
    print("wrote", out, f"(~{total:.1f}s)")
    return out


if __name__ == "__main__":
    js = build()
    subprocess.run([sys.executable, os.path.join(HERE, "assemble.py"), js, "--out",
                    os.path.join(DEMO, "crate_demo_v2_test.mp4")], check=True)
