#!/usr/bin/env python3
"""
take_v1.py -- scripted, prompt-free recording of the CRATE demo take on the
dedicated video simulator (never the user's device). One app launch, one
continuous take (inner + outer display recorded simultaneously), every app
action driven through the -crateCmdFile channel so it is repeatable:

  +2.0   dig "4 bar loop, j dilla laid back drums and a killer nujabes piano sample"
  +12    finger-drum accents on the beat grid (pads flash)
  +22    KEYS mode, 808 riff via semitone hits
  +31    back to SEQ + AI PERFORM on (crowd card reacts)
  +41    hinge sweep 110 -> 28 over 15 s  (filter closes)
  +57.6  snap open (DROP)
  +63    dig "fill up the pads with some house drums"
  +71    stop loop, +72.5 single calibration kick (for WAV <-> wall-clock sync)

Writes demo/clips/<take>_{inner,outer}.mp4 (+ .rec.json with wall-clock
start), demo/clips/<take>_app.wav (the app's master output, via
CRATE_DEBUG_WAV), demo/clips/console_<take>.log, demo/clips/<take>_events.json.

  python take_v1.py <udid> [take_name]
"""
import json
import os
import re
import subprocess
import sys
import time
import urllib.parse

HERE = os.path.dirname(os.path.abspath(__file__))
DEMO = os.path.abspath(os.path.join(HERE, "..", "..", "demo"))
CLIPS = os.path.join(DEMO, "clips")
CMD = "/tmp/crate-cmd-video.txt"
PY = sys.executable

UDID = sys.argv[1]
TAKE = sys.argv[2] if len(sys.argv) > 2 else "take1"
os.makedirs(CLIPS, exist_ok=True)
events = []


def mark(name, **kw):
    e = {"name": name, "t": time.time()}
    e.update(kw)
    events.append(e)
    print(f"{e['t']:.3f} {name} {kw}", flush=True)


def cmd(url):
    with open(CMD, "a") as f:
        f.write(url + "\n")
    mark("cmd", url=url)


def hinge(*args, bg=False):
    c = ["hinge", "-d", UDID] + [str(a) for a in args]
    mark("hinge", args=list(map(str, args)))
    if bg:
        return subprocess.Popen(c, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(c, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def wait_until(t):
    while True:
        d = t - time.time()
        if d <= 0:
            return
        time.sleep(min(d, 0.02))


def console_events(path):
    out = []
    try:
        for line in open(path, errors="ignore"):
            if line.startswith("CRATE "):
                try:
                    out.append(json.loads(line[6:]))
                except Exception:
                    pass
    except FileNotFoundError:
        pass
    return out


# ---------------------------------------------------------------- launch --
wav = os.path.join(CLIPS, f"{TAKE}_app.wav")
if os.path.exists(wav):
    os.remove(wav)
console = os.path.join(CLIPS, f"console_{TAKE}.log")
open(CMD, "w").close()
subprocess.run(["xcrun", "simctl", "terminate", UDID, "com.shuhan.crate"], capture_output=True)
hinge(110)
time.sleep(0.5)
env = dict(os.environ)
env["SIMCTL_CHILD_CRATE_DEBUG_WAV"] = wav
con_f = open(console, "w")
launch = subprocess.Popen(["xcrun", "simctl", "launch", "--console-pty", "--terminate-running-process", UDID,
                           "com.shuhan.crate", "-crateNoPaywall", "1", "-crateDebugLog", "1",
                           "-crateDebugRecord", "1", "-crateCmdFile", CMD],
                          stdout=con_f, stderr=subprocess.STDOUT, env=env)
mark("launch")
# wait for engine_start
for _ in range(100):
    ev = console_events(console)
    if any(e.get("event") == "cmd_channel" for e in ev):
        break
    time.sleep(0.1)
time.sleep(1.0)
cmd("crate://rot?deg=90")
cmd("crate://crowdrot?deg=0")
time.sleep(1.5)

# ---------------------------------------------------------------- record --
inner = os.path.join(CLIPS, f"{TAKE}_inner.mp4")
outer = os.path.join(CLIPS, f"{TAKE}_outer.mp4")
simrec = os.path.join(HERE, "simrec.py")
r1 = subprocess.Popen([PY, simrec, "rec", UDID, inner, "--display", "internal"])
r2 = subprocess.Popen([PY, simrec, "rec", UDID, outer, "--display", "1"])
for _ in range(100):
    ok = 0
    for p in (inner, outer):
        try:
            if "t_started" in json.load(open(os.path.splitext(p)[0] + ".rec.json")):
                ok += 1
        except Exception:
            pass
    if ok == 2:
        break
    time.sleep(0.1)
T0 = time.time()
mark("T0")

# ------------------------------------------------------------------ take --
wait_until(T0 + 2.0)
cmd("crate://dig?q=" + urllib.parse.quote("4 bar loop, j dilla laid back drums and a killer nujabes piano sample"))

# find loop start + bpm from the console
t_play, bpm = None, 92.0
for _ in range(60):
    for e in console_events(console):
        if e.get("event") == "play":
            t_play, bpm = e["t"], float(e.get("bpm", 92))
    if t_play:
        break
    time.sleep(0.1)
if not t_play:
    t_play = T0 + 2.3
mark("loop", t_play=t_play, bpm=bpm)
beat = 60.0 / bpm


def next_beat_after(t, sub=1):
    """time of the next grid point (beat/sub) after wall time t"""
    step = beat / sub
    n = int((t - t_play) / step) + 1
    return t_play + n * step


def hit_at(t, url, early=0.05):
    wait_until(t - early)
    cmd(url)


# finger drumming: accents, 2 bars of 8ths-ish pattern on top of the loop
t = next_beat_after(T0 + 12.0)
t = t_play + round((t - t_play) / (4 * beat)) * 4 * beat  # snap to bar
if t < T0 + 11.5:
    t += 4 * beat
fd = [  # (beat offset, pad)
    (0.0, 1), (0.5, 5), (1.0, 3), (1.5, 6), (2.0, 1), (2.75, 1), (3.0, 3), (3.5, 16),
    (4.0, 13), (4.5, 5), (5.0, 4), (5.5, 7), (6.0, 1), (6.5, 15), (7.0, 3), (7.25, 3), (7.5, 12),
    (8.0, 14), (9.0, 3), (10.0, 1), (10.5, 1), (11.0, 4), (11.5, 16),
]
mark("finger_start", t=t)
for off, pad in fd:
    hit_at(t + off * beat, f"crate://pad?i={pad}&b=A")
mark("finger_end")

# KEYS mode: 808 riff
t = t + 12 * beat + 0.4
wait_until(t)
cmd("crate://mode?m=keys")
t_k = t + 1.2
riff = [(0, 0), (1, 0), (1.5, 3), (2, 5), (3, 7), (4, 10), (5, 7), (5.5, 5), (6, 3), (7, 0),
        (8, 0), (9, 3), (10, 5), (10.5, 7), (11, 10), (12, 12)]
mark("keys_start", t=t_k)
for off, semi in riff:
    hit_at(t_k + off * beat, f"crate://pad?i=13&b=A&semi={semi}")
mark("keys_end")

# back to SEQ + AI perform (crowd card)
wait_until(t_k + 13 * beat + 0.3)
cmd("crate://mode?m=seq")
time.sleep(0.4)
cmd("crate://perform?on=1")
t_perf = time.time()
wait_until(t_perf + 9.5)
cmd("crate://perform?on=0")
time.sleep(0.8)

# hinge fold -> snap
T_FOLD = time.time() + 0.5
wait_until(T_FOLD)
mark("fold_start")
hp = hinge("sweep", 110, 28, 15.0, bg=True)
wait_until(T_FOLD + 16.6)
mark("snap")
hinge("sweep", 28, 110, 0.15)
hp.wait()
mark("snap_done")

# house drums swap
wait_until(T_FOLD + 16.6 + 5.0)
cmd("crate://dig?q=" + urllib.parse.quote("fill up the pads with some house drums"))
wait_until(T_FOLD + 16.6 + 13.0)

# calibration: stop, silence, one kick
cmd("crate://stop")
time.sleep(1.6)
cmd("crate://pad?i=1&b=A")
mark("calib_hit")
time.sleep(1.6)

# ------------------------------------------------------------------- stop --
subprocess.run([PY, simrec, "stop", inner, outer])
r1.wait(); r2.wait()
mark("rec_stopped")
json.dump({"events": events, "T0": T0, "t_play": t_play, "bpm": bpm}, open(os.path.join(CLIPS, f"{TAKE}_events.json"), "w"), indent=1)
print("done", flush=True)
