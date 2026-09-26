#!/usr/bin/env python3
"""
simrec.py -- tiny helpers for recording the CRATE demo takes on a dedicated
simulator, with wall-clock timestamps so the app's debug WAV (which has no
link to the video) can be aligned to each clip afterwards.

  python simrec.py rec <udid> <out.mp4> [--display internal|1]
      Runs `simctl io recordVideo` in the foreground (use & / background),
      writes <out>.rec.json with {"t_spawn", "t_started", "pid", "display"}
      as soon as the recorder reports "Recording started". Stop the recorder
      with `python simrec.py stop <out.mp4>` (SIGINT -> mp4 is finalised),
      after which "t_end" is added.

  python simrec.py stop <out.mp4> [...]

  python simrec.py cmd <cmdfile> <crate://url> [...]   append URL lines
"""
import json
import os
import signal
import subprocess
import sys
import time


def meta_path(out):
    return os.path.splitext(out)[0] + ".rec.json"


def rec(udid, out, display="internal"):
    t_spawn = time.time()
    p = subprocess.Popen(["xcrun", "simctl", "io", udid, "recordVideo", "--codec=h264",
                          f"--display={display}", "--force", out],
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
    meta = {"out": out, "udid": udid, "display": display, "t_spawn": t_spawn, "pid": p.pid}
    json.dump(meta, open(meta_path(out), "w"))
    log = []
    for line in p.stdout:
        now = time.time()
        log.append([now, line.rstrip()])
        if "Recording started" in line and "t_started" not in meta:
            meta["t_started"] = now
            json.dump(meta, open(meta_path(out), "w"))
    p.wait()
    meta["t_end"] = time.time()
    meta["log"] = log
    meta["rc"] = p.returncode
    json.dump(meta, open(meta_path(out), "w"), indent=1)


def stop(outs):
    for out in outs:
        try:
            meta = json.load(open(meta_path(out)))
            os.kill(meta["pid"], signal.SIGINT)
        except Exception as e:
            print("stop failed", out, e)
    # wait for files to be finalised
    for out in outs:
        for _ in range(100):
            try:
                if "t_end" in json.load(open(meta_path(out))):
                    break
            except Exception:
                pass
            time.sleep(0.1)


def cmd(path, urls):
    with open(path, "a") as f:
        for u in urls:
            f.write(u + "\n")


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[0] == "rec":
        disp = "internal"
        if "--display" in a:
            disp = a[a.index("--display") + 1]
        rec(a[1], a[2], disp)
    elif a[0] == "stop":
        stop(a[1:])
    elif a[0] == "cmd":
        cmd(a[1], a[2:])
