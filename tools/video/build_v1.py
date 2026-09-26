#!/usr/bin/env python3
"""
build_v1.py -- CRATE demo film v1: writes the resolved shot list
(demo/crate_demo_v1_shotlist.json, plain assemble.py format) and renders it.

Edit the SHOTS table / MIX numbers below and re-run:
  python tools/video/build_v1.py            # write json + render demo/crate_demo_v1.mp4
  python tools/video/build_v1.py --json     # only write the json
Or tweak the json by hand and re-render it directly:
  python tools/video/assemble.py demo/crate_demo_v1_shotlist.json --out demo/crate_demo_v1.mp4

Sources (all recorded on a throwaway "Duo-Video" simulator, see take_v1*.py,
prep_take.py, typing_intro.py, hinge_overlay.py):
  clips/take1_intro_{full,lid}.mov  typing reveal (4.1 s) + real footage from the DIG (take1 t=12.2 on)
  clips/take1_inner_up.mov / take1_deck.mov   laptop pose, upright, app audio muxed in
  clips/take3_outer_up.mov          back-screen crowd card (Dilla beat, AI PERFORM on)
  clips/take4_inner_up.mov / take4_lid.mov    punch-in FX ramp 0->95% (the hinge mapping), DROP at t=19.648
  clips/take*_app_aligned.wav       the app's master bus, sample 0 == that take's video t=0
Music: music/horn.wav (stored ~16 dB below full scale, hence the positive gains).
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEMO = os.path.abspath(os.path.join(HERE, "..", "..", "demo"))
PY = sys.executable

INTRO_TYPING = 4.1          # typing_intro.py: typing part length; intro t >= 4.1 <=> take1 t = intro t - 4.1 + 12.2
INTRO_DIG_SRC = 12.2
HOUSE_TYPING, HOUSE_DIG_SRC = 2.667, 24.10   # typing_intro.py --out take4_house_full.mov
BAR = 4 * 60 / 92.0          # take1/take4 loop: 92 BPM, 4/4
SONG_DELTA = 0.22           # the band's hit is on the beat at 143.22 s (measured), 0.22 s after 143.0
SNAP_T4 = 19.648            # take4 DROP event (video t)
FOLD = 16.6                 # SYNC: 143.0 - 126.4


def k(t, zoom, cx=0.5, cy=0.5):
    return {"t": t, "zoom": zoom, "cx": cx, "cy": cy}


def intro_to_take1(t):
    return t - INTRO_TYPING + INTRO_DIG_SRC


SHOTS = [
    {"type": "image", "id": "title", "path": "cards/title.png", "dur": 4.0,
     "keys": [k(0, 1.0), k(4.0, 1.05, 0.5, 0.46)]},
    # the prompt, typed into the lid's prompt line (push in on the line)
    {"type": "clip", "id": "type_prompt", "clip": "clips/take1_intro_lid.mov", "ss": 0.0, "dur": 4.4,
     "keys": [k(0, 1.12, 0.45, 0.72), k(4.4, 1.45, 0.377, 0.92)]},
    # Return -> pads fill instantly (whole laptop-pose device)
    {"type": "clip", "id": "pads_fill", "clip": "clips/take1_intro_full.mov", "ss": 3.95, "dur": 3.0,
     "keys": [k(0, 1.0), k(3.0, 1.07, 0.5, 0.45)]},
    # lid readout: JEV ~290 ms
    {"type": "clip", "id": "jev_readout", "clip": "clips/take1_intro_lid.mov", "ss": 5.3, "dur": 2.6,
     "keys": [k(0, 2.2, 0.83, 0.05), k(2.6, 2.7, 0.84, 0.04)]},
    # AI log: the GPT line lands (~1 s in)
    {"type": "clip", "id": "gpt_line", "clip": "clips/take1_intro_lid.mov", "ss": 7.9, "dur": 3.6,
     "keys": [k(0, 2.3, 0.78, 0.95), k(3.6, 1.9, 0.70, 0.92)]},
    {"type": "image", "id": "chapter_two_screens", "path": "cards/chapter_03.png", "dur": 2.4,
     "keys": [k(0, 1.0), k(2.4, 1.03, 0.45, 0.5)]},
    # finger drumming on the deck (take1 pad hits 23.0-30.5)
    {"type": "clip", "id": "finger_drum", "clip": "clips/take1_deck.mov", "ss": None, "dur": 8.6,
     "keys": [k(0, 1.0), k(8.6, 1.22, 0.47, 0.5)]},
    # KEYS mode: lid waveform + deck keyboard, both screens
    {"type": "clip", "id": "keys_mode", "clip": "clips/take1_inner_up.mov", "ss": None, "dur": 6.0,
     "keys": [k(0, 1.0), k(6.0, 1.12, 0.5, 0.5)]},
    # three screens: lid + deck + the back screen crowd card
    {"type": "clip", "id": "three_screens", "clip": "clips/take1_inner_up.mov", "ss": None, "dur": 7.0,
     "keys": [k(0, 1.0)], "second": "clips/take3_outer_up.mov", "second_ss": 0.4, "second_keys": [k(0, 1.0)],
     "frame_keys": [k(0, 1.0), k(7.0, 1.07, 0.5, 0.47)]},
    {"type": "image", "id": "chapter_hinge", "path": "cards/chapter_04.png", "dur": 2.4,
     "keys": [k(0, 1.0), k(2.4, 1.03, 0.45, 0.5)]},
    # the fold: punch-in FX ramps up (filter closes, reverb swells) -- ends exactly on the snap
    {"type": "clip", "id": "hinge_fold", "clip": "clips/take4_lid.mov", "ss": round(SNAP_T4 - FOLD, 3), "dur": FOLD,
     "keys": [k(0, 1.0), k(FOLD, 1.6, 0.31, 0.25)],
     "overlay": {"path": "cards/hinge_fold.mov", "x": 4, "y": 380}},
    # snap open = DROP (hard cut, camera already punched in, breathes out)
    {"type": "clip", "id": "snap_drop", "clip": "clips/take4_inner_up.mov", "ss": SNAP_T4 + 0.02, "dur": 3.0,
     "keys": [k(0, 1.3, 0.5, 0.32), k(3.0, 1.0)],
     "overlay": {"path": "cards/hinge_snap.mov", "x": 4, "y": 380}},
    # "fill up the pads with some house drums": typed on the lid, only the drums swap ("JEV 87ms drums only")
    {"type": "clip", "id": "house_type", "clip": "clips/take4_house_lid.mov", "ss": 0.0, "dur": 4.4,
     "keys": [k(0, 1.45, 0.34, 0.9), k(4.4, 1.55, 0.32, 0.93)]},
    # ...and the loop keeps going on the new house kit
    {"type": "clip", "id": "house_pads", "clip": "clips/take4_deck.mov", "ss": None, "dur": 3.2,
     "keys": [k(0, 1.0), k(3.2, 1.1, 0.47, 0.5)]},
    {"type": "video", "id": "end_typed", "path": "cards/end_typed.mov"},
    {"type": "image", "id": "end_card", "path": "cards/end_card.png", "dur": 6.0,
     "keys": [k(0, 1.0), k(6.0, 1.04, 0.5, 0.48)]},
]
END_TYPED_DUR = 2.5

# song gains are high because horn.wav peaks at -15.8 dBFS (~-25 LUFS in the intro)
MIX = {
    "song_intro_db": 8.0, "song_breakdown_db": 7.0, "song_drop_db": 10.0, "song_outro_db": 4.0,
    "app_db": -3.0, "app_fold_db": -1.0,
}


def build():
    # continuity: the app-audio section plays take1 continuously from the GPT
    # line through the second chapter card, so the shots inside it take their
    # ss from the running take clock.
    t, starts = 0.0, {}
    for s in SHOTS:
        starts[s["id"]] = t
        t += s.get("dur") or END_TYPED_DUR
    total = t
    S = {s["id"]: s for s in SHOTS}
    gpt = S["gpt_line"]
    tt = intro_to_take1(gpt["ss"] + gpt["dur"])            # take1 clock at the end of gpt_line
    tt += S["chapter_two_screens"]["dur"]
    for sid in ("finger_drum", "keys_mode"):
        S[sid]["ss"] = round(tt, 3)
        tt += S[sid]["dur"]
    # three_screens jumps exactly 2 bars ahead (92 BPM) into the AI PERFORM part of
    # the take (SEQ playhead running); a whole-bar jump keeps the groove's phase.
    keys_end_tt = tt
    tt += 2 * BAR
    S["three_screens"]["ss"] = round(tt, 3)
    tt += S["three_screens"]["dur"]
    S["house_pads"]["ss"] = round(S["house_type"]["ss"] + S["house_type"]["dur"] - HOUSE_TYPING + HOUSE_DIG_SRC, 3)
    for s in SHOTS:
        s.setdefault("audio", "silent")

    xf = starts["gpt_line"] + 1.5                             # crossfade song -> app, just after GPT lands
    app1_in = intro_to_take1(gpt["ss"] + 1.5)
    app1_end = starts["chapter_hinge"] + S["chapter_hinge"]["dur"]
    fold0 = starts["hinge_fold"]
    drop = starts["snap_drop"]
    house0 = starts["house_type"]
    endt = starts["end_typed"]
    music = [
        {"file": "music/horn.wav", "at": 0.0, "track_in": 0.0, "dur": round(xf + 2.5, 3),
         "gain_db": MIX["song_intro_db"], "fade_in": 0.3, "fade_out": 2.5, "note": "L1 song intro under title/prompt/pads"},
        {"file": "clips/take1_app_aligned.wav", "at": round(xf, 3), "track_in": round(app1_in, 3),
         "dur": round(starts["three_screens"] - xf + 0.02, 3), "gain_db": MIX["app_db"], "fade_in": 1.5, "fade_out": 0.03,
         "note": "APP1a CRATE's own beat, take1 continuous: gpt line -> card -> finger drum -> keys"},
        {"file": "clips/take1_app_aligned.wav", "at": round(starts["three_screens"], 3), "track_in": S["three_screens"]["ss"],
         "dur": round(app1_end - starts["three_screens"], 3), "gain_db": MIX["app_db"], "fade_in": 0.03, "fade_out": 2.2,
         "note": "APP1b take1 two bars later (AI PERFORM), under three screens + the hinge card"},
        {"file": "music/horn.wav", "at": round(starts["chapter_hinge"], 3),
         "track_in": round(126.4 + SONG_DELTA - (fold0 - starts["chapter_hinge"]), 3),
         "dur": round(drop - starts["chapter_hinge"], 3), "gain_db": MIX["song_breakdown_db"],
         "fade_in": 2.0, "fade_out": 0.02, "note": "L2 SYNC: breakdown under the fold (song 126.62 on its first frame, so 143.22 lands on the snap)"},
        {"file": "clips/take4_app_aligned.wav", "at": round(fold0, 3), "track_in": S["hinge_fold"]["ss"],
         "dur": FOLD, "gain_db": MIX["app_fold_db"], "fade_in": 0.4, "fade_out": 2.5,
         "note": "APP2 the fold: filter closing, reverb swelling (fades as the breakdown takes over)"},
        {"file": "music/horn.wav", "at": round(drop, 3), "track_in": round(143.0 + SONG_DELTA, 3), "dur": round(S["snap_drop"]["dur"] + 1.6, 3),
         "gain_db": MIX["song_drop_db"], "fade_in": 0.005, "fade_out": 1.8,
         "note": "L3 SYNC: the band re-enters (143.0 s section, first hit 143.22) on the snap-open frame = DROP"},
        {"file": "clips/take4_app_aligned.wav", "at": round(house0 + 0.3, 3),
         "track_in": round(S["house_type"]["ss"] + 0.3 - HOUSE_TYPING + HOUSE_DIG_SRC, 3),
         "dur": round(S["house_type"]["dur"] + S["house_pads"]["dur"] - 0.3 + 1.6, 3), "gain_db": MIX["app_db"],
         "fade_in": 1.2, "fade_out": 1.6, "note": "APP3 loop keeps going, house drums swap in at the DIG"},
        {"file": "music/horn.wav", "at": round(endt - 0.3, 3), "track_in": 8.0, "dur": round(total - endt + 0.3, 3),
         "gain_db": MIX["song_outro_db"], "fade_in": 1.5, "fade_out": 3.0, "note": "L4 quiet reprise under the end cards"},
    ]
    cfg = {"w": 1920, "h": 1080, "fps": 30, "shots": SHOTS, "music": music,
           "_timeline_estimate": {sid: round(v, 3) for sid, v in starts.items()}, "_total_estimate": round(total, 3)}
    out = os.path.join(DEMO, "crate_demo_v1_shotlist.json")
    json.dump(cfg, open(out, "w"), indent=1)
    print("wrote", out, f"(~{total:.1f}s)")
    return out


def main():
    js = build()
    if "--json" in sys.argv:
        return
    subprocess.run([PY, os.path.join(HERE, "assemble.py"), js, "--out", os.path.join(DEMO, "crate_demo_v1.mp4")], check=True)


if __name__ == "__main__":
    main()
