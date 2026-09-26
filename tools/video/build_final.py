#!/usr/bin/env python3
"""build_final.py -- the submitted CRATE film: title -> song 1 (dilla x nujabes jazz,
jazz take (current UI): dig, GPT upgrade, finger drums, KEYS, AI PERFORM) -> song 2 (deep house 124,
take song2: dig, KEYS stabs, PAD FX build, snap DROP; dropback: back-screen DROP)
-> end cards. Song audio = the app's own master bus; horn.wav only intro/bridge/outro.

  ~/vlogcut/.venv/bin/python3 tools/video/build_final.py
"""
import json, os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
DEMO = os.path.abspath(os.path.join(HERE, "..", "..", "demo"))
BAR1 = 4 * 60 / 92.0


def k(t, zoom, cx=0.5, cy=0.5):
    return {"t": t, "zoom": zoom, "cx": cx, "cy": cy}


def ks(t, zoom, screen, u, v):
    return {"t": t, "zoom": zoom, "screen": screen, "u": u, "v": v}


LAPTOP = {"pose": "laptop", "view": "front", "az": 9}
LAPTOP_DECK = {"pose": "laptop", "view": "front", "el": 38}
J = "clips/jazz_inner_up.mov"
S2 = "clips/song2_inner_up.mov"
PADS_SS = 23.52
KEYS_SS = 31.22
THREE_SS = 43.17
KEYS_DUR = round(THREE_SS - BAR1 - KEYS_SS, 3)
S2_SS = 2.6
S2_DROP = 23.63
SHOTS = [
    {"type": "image", "id": "title", "path": "cards/title_tag.png", "dur": 3.5, "keys": [k(0, 1.0), k(3.5, 1.04, 0.5, 0.47)]},
    {"type": "clip", "id": "s1_dig", "clip": J, "ss": 0.8, "dur": 4.2, "keys": [k(0, 1.0), k(4.2, 1.12, 0.5, 0.42)]},
    {"type": "clip", "id": "s1_gpt", "clip": J, "ss": 5.0, "dur": 4.5, "keys": [k(0, 1.3, 0.45, 0.33), k(4.5, 1.7, 0.35, 0.36)]},
    {"type": "device", "id": "s1_drums_dev", "device": LAPTOP_DECK, "clip": J, "ss": 9.5, "dur": 3.0,
     "keys": [ks(0, 2.05, "deck", 0.43, 0.55), ks(3.0, 2.25, "deck", 0.45, 0.58)]},
    {"type": "clip", "id": "s1_drums_flat", "clip": J, "ss": 12.5, "dur": 2.3, "keys": [k(0, 1.35, 0.5, 0.72), k(2.3, 1.42, 0.5, 0.73)]},
    {"type": "clip", "id": "s1_keys", "clip": J, "ss": 14.8, "dur": 5.3, "keys": [k(0, 1.0), k(5.3, 1.3, 0.5, 0.64)]},
    {"type": "device", "id": "s1_perform_dev", "device": LAPTOP, "clip": J, "ss": 20.1, "dur": 5.0,
     "keys": [k(0, 1.0), k(5.0, 1.06, 0.5, 0.48)]},
    {"type": "clip", "id": "s1_perform_lid", "clip": J, "ss": 25.1, "dur": 5.4, "keys": [k(0, 1.4, 0.5, 0.27), k(5.4, 1.55, 0.5, 0.27)]},
    {"type": "image", "id": "chapter_hinge", "path": "cards/chapter_04.png", "dur": 2.4, "keys": [k(0, 1.0), k(2.4, 1.03)]},
    {"type": "clip", "id": "s2_dig", "clip": S2, "ss": S2_SS - 1.0, "dur": 6.0, "keys": [k(0, 1.0), k(6.0, 1.08)]},
    {"type": "device_anim", "id": "s2_fx_build", "device": LAPTOP, "clip": S2, "ss": 13.406, "dur": 10.224,
     "open_keys": [{"t": 0.0, "deg": 110.0}, {"t": 2.54, "deg": 110.0}, {"t": 2.94, "deg": 107.3}, {"t": 3.34, "deg": 104.0}, {"t": 3.74, "deg": 100.5}, {"t": 4.24, "deg": 95.8}, {"t": 4.64, "deg": 91.9}, {"t": 5.14, "deg": 86.8}, {"t": 5.64, "deg": 81.6}, {"t": 6.14, "deg": 76.3}, {"t": 6.64, "deg": 70.9}, {"t": 7.14, "deg": 65.4}, {"t": 7.54, "deg": 60.9}, {"t": 8.04, "deg": 55.2}, {"t": 8.54, "deg": 50.6}, {"t": 8.94, "deg": 44.7}, {"t": 9.44, "deg": 38.9}, {"t": 9.94, "deg": 32.8}, {"t": 10.224, "deg": 30.4}],
     "keys": [k(0, 1.0), k(10.224, 1.12, 0.5, 0.5)], "screens": {"lid": {"crop": "lid"}, "deck": {"crop": "deck"}}},
    {"type": "device_anim", "id": "s2_snap", "device": LAPTOP, "clip": S2, "ss": S2_DROP, "dur": 3.0,
     "open_keys": [{"t": 0, "deg": 30.4}, {"t": 0.15, "deg": 110}, {"t": 3.0, "deg": 110}],
     "keys": [k(0, 1.12, 0.5, 0.5), k(3.0, 1.0)], "screens": {"lid": {"crop": "lid"}, "deck": {"crop": "deck"}}},
    {"type": "clip", "id": "s2_drop", "clip": S2, "ss": S2_DROP + 3.0, "dur": 6.0, "keys": [k(0, 1.35, 0.5, 0.3), k(6.0, 1.2, 0.5, 0.35)]},
    {"type": "clip", "id": "s2_dropback", "clip": "clips/dropback_outer_up.mov", "ss": 5.6, "dur": 5.5, "keys": [k(0, 1.0), k(5.5, 1.04)]},
    {"type": "video", "id": "end_typed", "path": "cards/end_typed.mov"},
    {"type": "image", "id": "end_card", "path": "cards/end_card.png", "dur": 6.5, "keys": [k(0, 1.0), k(6.5, 1.04, 0.5, 0.48)]},
]


def build():
    t, st = 0.0, {}
    for s in SHOTS:
        s.setdefault("audio", "silent")
        st[s["id"]] = t
        t += s.get("dur", 2.5)
    S = {s["id"]: s for s in SHOTS}
    app1 = "clips/jazz_app_aligned.wav"
    app2 = "clips/song2_app_aligned.wav"
    s1_a = st["s1_dig"]; s1_end = st["chapter_hinge"]
    s2_a = st["s2_dig"]; s2_end = st["s2_dropback"]
    music = [
        {"file": "music/horn.wav", "at": 0.0, "track_in": 0.0, "dur": round(s1_a, 3), "gain_db": 8.0, "fade_in": 0.3, "fade_out": 0.7},
        {"file": app1, "at": s1_a, "track_in": 0.8, "dur": round(s1_end - s1_a + 1.2, 3), "gain_db": -3.0, "fade_in": 0.05, "fade_out": 1.6},
        {"file": "music/horn.wav", "at": round(st["chapter_hinge"] - 0.4, 3), "track_in": 60.0, "dur": round(s2_a - st["chapter_hinge"] + 2.2, 3), "gain_db": 8.0, "fade_in": 0.6, "fade_out": 1.4},
        {"file": app2, "at": s2_a, "track_in": S2_SS - 1.0, "dur": 6.0, "gain_db": -3.0, "fade_in": 0.8, "fade_out": 0.03},
        {"file": app2, "at": st["s2_fx_build"], "track_in": 13.406, "dur": round(s2_end - st["s2_fx_build"] + 0.02, 3), "gain_db": -3.0, "fade_in": 0.03, "fade_out": 0.02},
        {"file": "clips/dropback_outer_up.mov", "at": s2_end, "track_in": 5.6, "dur": 5.5 + 1.5, "gain_db": -3.0, "fade_in": 0.02, "fade_out": 1.8},
        {"file": "music/horn.wav", "at": round(st["end_typed"] - 0.8, 3), "track_in": 8.0, "dur": round(t - st["end_typed"] + 0.8, 3), "gain_db": 6.0, "fade_in": 1.2, "fade_out": 2.5},
    ]
    cfg = {"w": 1920, "h": 1080, "fps": 30, "shots": SHOTS, "music": music, "_total_estimate": round(t, 3)}
    out = os.path.join(DEMO, "crate_demo_final_shotlist.json")
    json.dump(cfg, open(out, "w"), indent=1)
    print("wrote", out, f"(~{t:.1f}s)")
    return out


if __name__ == "__main__":
    js = build()
    subprocess.run([sys.executable, os.path.join(HERE, "assemble.py"), js, "--out",
                    os.path.join(DEMO, "crate_demo_final.mp4")], check=True)
