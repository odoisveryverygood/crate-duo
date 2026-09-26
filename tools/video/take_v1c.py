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


def start_rec(path, display):
    p = subprocess.Popen([PY, simrec, "rec", UDID, path, "--display", display])
    for _ in range(100):
        try:
            if "t_started" in json.load(open(os.path.splitext(path)[0] + ".rec.json")):
                break
        except Exception:
            pass
        time.sleep(0.05)
    return p


# 1. outer display: crowd card while the Dilla beat plays with AI PERFORM on
cmd("crate://dig?q=" + urllib.parse.quote("4 bar loop, j dilla laid back drums and a killer nujabes piano sample"))
time.sleep(2.0)
cmd("crate://perform?on=1")
r2 = start_rec(outer, "1")
mark("outer_rec")
time.sleep(13.0)
subprocess.run([PY, simrec, "stop", outer]); r2.wait()
cmd("crate://perform?on=0")
mark("outer_stopped")
time.sleep(0.5)

# 2. inner display: punch-in FX ramp (what the hinge drives), snap back = DROP,
#    then the house-drums swap. The simulated hinge itself blanks the inner
#    display while it moves, so the fold is driven through crate://punch.
r1 = start_rec(inner, "internal")
T0 = time.time()
mark("T0")
wait_until(T0 + 3.0)
T_FOLD = time.time()
mark("fold_start")
N = 150                     # 15 s ramp at 10 Hz
for i in range(N + 1):
    wait_until(T_FOLD + i * 0.1)
    p = 0.95 * (i / N) ** 1.15
    with open(CMD, "a") as f:
        f.write(f"crate://punch?p={p:.3f}\n")
mark("fold_done")
wait_until(T_FOLD + 16.6)
cmd("crate://punch?p=0")
mark("snap")
wait_until(T_FOLD + 16.6 + 4.5)
cmd("crate://dig?q=" + urllib.parse.quote("fill up the pads with some house drums"))
wait_until(T_FOLD + 16.6 + 13.0)
subprocess.run([PY, simrec, "stop", inner]); r1.wait()
mark("rec_stopped")
json.dump({"events": events, "T0": T0, "T_FOLD": T_FOLD}, open(os.path.join(CLIPS, f"{TAKE}_events.json"), "w"), indent=1)
print("done", flush=True)
