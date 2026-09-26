#!/usr/bin/env python3
"""
prep_take.py -- turn a raw simctl take into edit-ready clips.

  python prep_take.py <take> [--calib]

  * <take>_inner.mp4 (VFR, rotation flag) -> <take>_inner_up.mov: CFR 30 fps,
    read with -noautorotate (the stored frames are already the upright
    laptop-pose view: lid on top, deck below), the debug overlay strip down
    the left edge painted out, and the app's own audio muxed in, aligned to
    the picture.
  * <take>_outer.mp4 -> <take>_outer_up.mov (same, no audio).

Audio alignment: the app writes its master bus to <take>_app.wav starting
at (roughly) its engine_start. The exact wall-clock time of WAV sample 0 is
recovered from the calibration hit at the end of the take (loop stopped,
one kick): t_wav0 = t(pad event) - onset_in_wav. Video t=0 is the wall time
simrec.py logged when simctl reported "Recording started".
"""
import json
import os
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
DEMO = os.path.abspath(os.path.join(HERE, "..", "..", "demo"))
CLIPS = os.path.join(DEMO, "clips")
SR = 48000
DEBUG_STRIP = "drawbox=x=0:y=0:w=52:h=1010:color=black:t=fill"


def sh(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode:
        print(" ".join(cmd)); print(r.stderr[-3000:])
        raise SystemExit(1)
    return r.stdout


def events(take):
    out = []
    for line in open(os.path.join(CLIPS, f"console_{take}.log"), errors="ignore"):
        if line.startswith("CRATE "):
            try:
                out.append(json.loads(line[6:]))
            except Exception:
                pass
    return out


def read_wav_mono(path):
    raw = sh(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"])
    return None


def wav_array(path):
    p = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
                       capture_output=True)
    return np.frombuffer(p.stdout, dtype=np.float32)


def onset_near(x, t_guess, win=1.2):
    a = max(0, int((t_guess - win) * SR)); b = min(len(x), int((t_guess + win) * SR))
    seg = np.abs(x[a:b])
    if len(seg) == 0:
        return None
    blk = 48
    env = seg[: len(seg) // blk * blk].reshape(-1, blk).max(axis=1)
    noise = np.median(env[: max(5, len(env) // 5)]) + 1e-5
    thr = max(noise * 8, env.max() * 0.2)
    idx = np.argmax(env > thr)
    return (a + idx * blk) / SR


def main():
    take = sys.argv[1]
    ev = events(take)
    rec = json.load(open(os.path.join(CLIPS, f"{take}_inner.rec.json")))
    t_v0 = rec["t_started"]
    eng = [e for e in ev if e.get("event") == "engine_start"][0]["t"]
    wav = os.path.join(CLIPS, f"{take}_app.wav")
    x = wav_array(wav)
    # sync: WAV is silent until the first DIG starts the loop; the loop's first
    # hit lands on the "play" event, so t_wav0 = t(play) - first onset.
    t_play = [e for e in ev if e.get("event") == "play"][0]["t"]
    on = float(np.argmax(np.abs(x) > 0.01)) / SR
    t_wav0 = t_play - on
    print(f"engine_start {eng:.3f}  play {t_play:.3f}  first onset {on:.3f}s -> t_wav0 {t_wav0:.3f} (engine{t_wav0 - eng:+.3f})")
    off = t_v0 - t_wav0          # wav position at video t=0
    print(f"video t0 {t_v0:.3f}  -> wav offset {off:.3f}s")
    aligned = os.path.join(CLIPS, f"{take}_app_aligned.wav")
    if off >= 0:
        af = f"atrim=start={off:.6f},asetpts=PTS-STARTPTS"
    else:
        af = f"adelay={int(-off * 1000)}|{int(-off * 1000)}"
    sh(["ffmpeg", "-v", "error", "-y", "-i", wav, "-af", af, "-ar", str(SR), "-ac", "2", "-c:a", "pcm_s16le", aligned])

    up = os.path.join(CLIPS, f"{take}_inner_up.mov")
    sh(["ffmpeg", "-v", "error", "-y", "-noautorotate", "-i", os.path.join(CLIPS, f"{take}_inner.mp4"), "-i", aligned,
        "-map", "0:v", "-map", "1:a", "-vf", f"fps=30,{DEBUG_STRIP},format=yuv420p",
        "-c:v", "libx264", "-preset", "veryfast", "-crf", "14", "-c:a", "pcm_s16le",
        "-metadata:s:v:0", "rotate=0", "-shortest", up])
    print("wrote", up)
    outer = os.path.join(CLIPS, f"{take}_outer.mp4")
    if os.path.exists(outer):
        oup = os.path.join(CLIPS, f"{take}_outer_up.mov")
        sh(["ffmpeg", "-v", "error", "-y", "-noautorotate", "-i", outer, "-vf", "fps=30,format=yuv420p",
            "-c:v", "libx264", "-preset", "veryfast", "-crf", "14", "-an", "-metadata:s:v:0", "rotate=0", oup])
        print("wrote", oup)
    # timeline helpers: key events in VIDEO time
    keyev = {}
    for e in ev:
        n = e.get("event")
        if n in ("dig_start", "play", "gpt", "drop", "perform", "load_bank", "jev_plan") or (n == "url" and e.get("cmd") in ("mode", "perform", "dig", "stop")):
            keyev.setdefault(n if n != "url" else "url_" + e.get("cmd"), []).append(round(e["t"] - t_v0, 3))
    hinge = [(round(e["t"] - t_v0, 3), e["deg"]) for e in ev if e.get("event") == "hinge"]
    json.dump({"t_v0": t_v0, "t_wav0": t_wav0, "events_video_t": keyev, "hinge": hinge},
              open(os.path.join(CLIPS, f"{take}_timing.json"), "w"), indent=1)
    for k, v in keyev.items():
        print(k, v[:12])


if __name__ == "__main__":
    main()
