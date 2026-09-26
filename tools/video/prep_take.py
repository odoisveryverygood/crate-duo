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


ENGINE_TO_WAV0 = -0.036   # measured twice on v1 takes: WAV sample 0 = engine_start - 36 ms


def main():
    take = sys.argv[1]
    ev = events(take)
    inner_rec = os.path.join(CLIPS, f"{take}_inner.rec.json")
    outer_rec = os.path.join(CLIPS, f"{take}_outer.rec.json")
    eng = [e for e in ev if e.get("event") == "engine_start"][0]["t"]
    t_wav0 = eng + ENGINE_TO_WAV0
    wav = os.path.join(CLIPS, f"{take}_app.wav")
    have_wav = os.path.exists(wav)
    if have_wav:
        x = wav_array(wav)
        plays = [e for e in ev if e.get("event") in ("play", "pattern")]
        if plays and np.any(np.abs(x) > 0.01):
            on = float(np.argmax(np.abs(x) > 0.01)) / SR
            cross = plays[0]["t"] - on
            print(f"sync check: engine-based t_wav0 {t_wav0:.3f}, onset-based {cross:.3f} (diff {cross - t_wav0:+.3f}s)")
    out = {"t_wav0": t_wav0, "events": ev}
    for kind, recp in (("inner", inner_rec), ("outer", outer_rec)):
        if not os.path.exists(recp):
            continue
        rec = json.load(open(recp))
        if "t_started" not in rec:
            continue
        t_v0 = rec["t_started"]
        src = os.path.join(CLIPS, f"{take}_{kind}.mp4")
        up = os.path.join(CLIPS, f"{take}_{kind}_up.mov")
        off = t_v0 - t_wav0
        cmd = ["ffmpeg", "-v", "error", "-y", "-noautorotate", "-i", src]
        if have_wav:
            af = f"atrim=start={off:.6f},asetpts=PTS-STARTPTS" if off >= 0 else f"adelay={int(-off * 1000)}|{int(-off * 1000)}"
            cmd += ["-i", wav, "-map", "0:v", "-map", "1:a", "-af", af + ",aresample=48000", "-ac", "2", "-c:a", "pcm_s16le"]
        else:
            cmd += ["-an"]
        vf = f"fps=30,{DEBUG_STRIP},format=yuv420p" if kind == "inner" else "fps=30,format=yuv420p"
        cmd += ["-vf", vf, "-c:v", "libx264", "-preset", "veryfast", "-crf", "14", "-metadata:s:v:0", "rotate=0"]
        if have_wav:
            cmd += ["-shortest"]
        cmd += [up]
        sh(cmd)
        print("wrote", up, f"(video t0 {t_v0:.3f}, wav offset {off:+.3f}s)")
        out[f"t_v0_{kind}"] = t_v0
        if have_wav and kind == "inner":
            aligned = os.path.join(CLIPS, f"{take}_app_aligned.wav")
            af = f"atrim=start={off:.6f},asetpts=PTS-STARTPTS" if off >= 0 else f"adelay={int(-off * 1000)}|{int(-off * 1000)}"
            sh(["ffmpeg", "-v", "error", "-y", "-i", wav, "-af", af, "-ar", str(SR), "-ac", "2", "-c:a", "pcm_s16le", aligned])
    json.dump(out, open(os.path.join(CLIPS, f"{take}_timing.json"), "w"), indent=1)
    t0 = out.get("t_v0_inner", out.get("t_v0_outer"))
    for e in ev:
        n = e.get("event")
        if n in ("url", "play", "pattern", "gpt", "drop", "dig_start", "jev_plan", "load_bank", "import", "flip") :
            q = e.get("q", "")
            print(f"  {e['t'] - t0:8.3f}  {n:10s} {e.get('cmd', '')} {q[:60] if isinstance(q, str) else ''}")


if __name__ == "__main__":
    main()
