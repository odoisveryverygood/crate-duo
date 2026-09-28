#!/usr/bin/env python3
"""bitrig_fx_take.py -- record a hinge-FX take in Bitrig's 3D iPhone Duo: the app's master bus
(debug WAV) + a screen recording of Bitrig's device pane, with the fold / snap driven through
the simulator hinge. Writes demo/raw/fx_<name>.mov + .wav + .json (wall-clock times for sync).

  python bitrig_fx_take.py <name> <fx> [--project HOUSE] [--region x,y,w,h] [--build 5] [--low 64]
"""
import json
import os
import subprocess
import sys
import time

B = os.path.expanduser("~/Library/Application Support/app.bitrig.bitrigapp/SimulatorHost/Devices")
D = "9193E59E-E5A1-449D-BF60-C48438FE33AC"
HELPER = next(os.path.join(os.path.expanduser("~/.cache/hinge"), f) for f in os.listdir(os.path.expanduser("~/.cache/hinge"))
              if f.startswith("hinge_helper-"))
CMD = "/tmp/crate-cmd-bitrig.txt"
RAW = os.path.expanduser("~/crate-build/demo/raw")
os.makedirs(RAW, exist_ok=True)

args = sys.argv[1:]
name, fx = args[0], args[1]


def opt(k, d):
    return args[args.index(k) + 1] if k in args else d


project = opt("--project", "HOUSE")
region = opt("--region", "611,166,1000,1000")
build = float(opt("--build", "5"))
low = float(opt("--low", "64"))
rest = 110.0
log = {}


def mark(k):
    log[k] = time.time()


def cmd(url):
    with open(CMD, "a") as f:
        f.write(url + "\n")


def hinge(*a, wait=True):
    p = subprocess.Popen(["xcrun", "simctl", "--set", B, "spawn", D, HELPER, *map(str, a)])
    if wait:
        p.wait()
    return p


wav = os.path.join(RAW, f"fx_{name}.wav")
mov = os.path.join(RAW, f"fx_{name}.mov")
for f in (wav, mov):
    if os.path.exists(f):
        os.remove(f)
open(CMD, "w").close()
env = dict(os.environ, SIMCTL_CHILD_CRATE_DEBUG_WAV=wav)
subprocess.run(["xcrun", "simctl", "--set", B, "launch", "--terminate-running-process", D, "com.shuhan.crate",
                "-crateNoPaywall", "1", "-crateDebugRecord", "1", "-crateCmdFile", CMD, "-crateDebugLog", "1"],
               env=env, capture_output=True)
mark("launch")
time.sleep(6)
hinge("set", rest)
cmd(f"crate://project?cmd=open&name={project}")
time.sleep(2.5)
cmd("crate://mode?m=padfx")
cmd(f"crate://fx?t={fx}")
cmd("crate://play")
time.sleep(2.0)
dur = 3.0 + build + 0.7 + 5.0
rec = subprocess.Popen(["screencapture", "-v", "-x", "-V", str(int(dur + 1)), "-R", region, mov])
mark("rec_start")
time.sleep(3.0)
mark("build_start")
hinge("sweep", rest, low, build)
time.sleep(0.6)
mark("snap")
hinge("sweep", low, rest, 0.12)
time.sleep(5.0)
rec.wait()
mark("rec_end")
cmd("crate://stop")
time.sleep(1.0)
json.dump({"name": name, "fx": fx, "project": project, "build": build, "low": low, **log},
          open(os.path.join(RAW, f"fx_{name}.json"), "w"), indent=1)
print(json.dumps(log, indent=1))
