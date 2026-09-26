#!/usr/bin/env python3
"""
take_v3.py -- scripted, prompt-free takes for the v3 film (two songs), on the
dedicated video simulator (never the user's device). Every app action goes
through the -crateCmdFile channel; musical actions are scheduled on the
loop's own bar grid (read from the console's "play" event + bpm) so pad hits,
chords and the DROP land on beats.

  python take_v3.py <udid> song1   [--song /abs/dancing_queen_4bar.wav] [--drums-bank A]
  python take_v3.py <udid> song2   [--bars-build 4]
  python take_v3.py <udid> dropback                 # back screen during a ramp + snap (DROP flash)
  python take_v3.py <udid> paywall                  # no -crateNoPaywall: DIG until the paywall shows

Writes demo/clips/<take>_inner.mp4 (+ _outer.mp4 where relevant), .rec.json
wall-clock starts, <take>_app.wav (the app's master bus), console_<take>.log,
<take>_events.json. Then: python prep_take.py <take>
"""
import json
import os
import subprocess
import sys
import time
import urllib.parse

HERE = os.path.dirname(os.path.abspath(__file__))
DEMO = os.path.abspath(os.path.join(HERE, "..", "..", "demo"))
CLIPS = os.path.join(DEMO, "clips")
CMD = "/tmp/crate-cmd-video.txt"
PY = sys.executable
SIMREC = os.path.join(HERE, "simrec.py")

args = sys.argv[1:]
UDID, KIND = args[0], args[1]


def opt(name, default=None):
    return args[args.index(name) + 1] if name in args else default


TAKE = opt("--take", KIND)
SONG = opt("--song", "/Users/shuhanzhang/crate-build/demo/songs/dancing_queen_4bar.wav")
DRUMS_BANK = opt("--drums-bank", "A")
BUILD_BARS = int(opt("--bars-build", "8"))
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


def wait_until(t):
    while True:
        d = t - time.time()
        if d <= 0:
            return
        time.sleep(min(d, 0.01))


def console(path):
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


def wait_event(path, name, after, timeout=15.0):
    t_end = time.time() + timeout
    while time.time() < t_end:
        for e in console(path):
            if e.get("event") == name and e["t"] >= after:
                return e
        time.sleep(0.05)
    return None


def start_rec(path, display):
    p = subprocess.Popen([PY, SIMREC, "rec", UDID, path, "--display", display])
    for _ in range(200):
        try:
            if "t_started" in json.load(open(os.path.splitext(path)[0] + ".rec.json")):
                break
        except Exception:
            pass
        time.sleep(0.05)
    return p


def stop_rec(path, proc):
    subprocess.run([PY, SIMREC, "stop", path])
    proc.wait()


# ---------------------------------------------------------------- launch --
wav = os.path.join(CLIPS, f"{TAKE}_app.wav")
if os.path.exists(wav):
    os.remove(wav)
con = os.path.join(CLIPS, f"console_{TAKE}.log")
open(CMD, "w").close()
subprocess.run(["xcrun", "simctl", "terminate", UDID, "com.shuhan.crate"], capture_output=True)
time.sleep(0.3)
env = dict(os.environ)
env["SIMCTL_CHILD_CRATE_DEBUG_WAV"] = wav
flags = ["-crateDebugLog", "1", "-crateDebugRecord", "1", "-crateCmdFile", CMD]
if KIND != "paywall":
    flags = ["-crateNoPaywall", "1"] + flags
con_f = open(con, "w")
subprocess.Popen(["xcrun", "simctl", "launch", "--console-pty", "--terminate-running-process", UDID,
                  "com.shuhan.crate"] + flags, stdout=con_f, stderr=subprocess.STDOUT, env=env)
mark("launch")
for _ in range(150):
    if any(e.get("event") == "cmd_channel" for e in console(con)):
        break
    time.sleep(0.1)
time.sleep(2.2)                    # no DROP detection in the first 2 s after launch
cmd("crate://rot?deg=90")
cmd("crate://crowdrot?deg=0")
time.sleep(1.2)

inner = os.path.join(CLIPS, f"{TAKE}_inner.mp4")
outer = os.path.join(CLIPS, f"{TAKE}_outer.mp4")


class Grid:
    def __init__(self, t_play, bpm):
        self.t0, self.beat = t_play, 60.0 / bpm
        self.bar = 4 * self.beat

    def next_bar(self, t, plus=0):
        n = int((t - self.t0) / self.bar) + 1
        return self.t0 + (n + plus) * self.bar


def grid_from_play(after, default_bpm):
    """the loop's grid: first "play" event after `after` (bpm from it or from the
    latest "pattern" event carrying a bpm)"""
    t_end = time.time() + 20
    while time.time() < t_end:
        ev = [e for e in console(con) if e["t"] >= after]
        play = next((e for e in ev if e.get("event") == "play"), None)
        pat = [e for e in ev if e.get("event") == "pattern" and "bpm" in e]
        if play or pat:
            t0 = play["t"] if play else pat[0]["t"]
            bpm = float(play.get("bpm") or (pat[-1]["bpm"] if pat else default_bpm)) if play else float(pat[-1]["bpm"])
            return Grid(t0, bpm)
        time.sleep(0.05)
    return Grid(time.time(), default_bpm)


def hits(grid, t_bar, pattern, url_fn, early=0.05):
    for beat_off, arg in pattern:
        wait_until(t_bar + beat_off * grid.beat - early)
        cmd(url_fn(arg))


if KIND == "song1":
    r1 = start_rec(inner, "internal")
    T0 = time.time(); mark("T0")
    wait_until(T0 + 1.5)
    cmd("crate://import?path=" + urllib.parse.quote(SONG))
    g = grid_from_play(T0, 94.0)
    mark("grid", t0=g.t0, bar=g.bar)
    time.sleep(0.3)
    cmd("crate://bank?b=D")                       # the 16 chops on the deck
    # the AI's flip plays for 2 bars, then "dilla drums for this"
    t = g.next_bar(time.time(), plus=3)          # let the flip play ~4 bars first
    wait_until(t - 0.3)
    cmd("crate://dig?q=" + urllib.parse.quote("dilla drums for this"))
    gpt = wait_event(con, "gpt", t - 1, timeout=14)
    mark("gpt", ok=bool(gpt))
    # finger drumming: 2 bars on the drum bank, on the grid
    tb = g.next_bar(time.time(), plus=1)
    wait_until(tb - 1.0)
    cmd(f"crate://bank?b={DRUMS_BANK}")          # show the drum pads being played
    pat = [(0.0, 1), (0.5, 5), (1.0, 3), (1.5, 6), (2.0, 1), (2.75, 1), (3.0, 3), (3.5, 16),
           (4.0, 13), (4.5, 5), (5.0, 4), (5.5, 7), (6.0, 1), (6.5, 15), (7.0, 3), (7.25, 3), (7.5, 12)]
    mark("finger_start", t=tb)
    hits(g, tb, pat, lambda i: f"crate://pad?i={i}&b={DRUMS_BANK}")
    wait_until(tb + 2 * g.bar + 4 * g.bar)       # 4 more bars for the "sing over it" moment
    stop_rec(inner, r1)
    mark("inner_stopped")
    r2 = start_rec(outer, "1")                   # the back screen with the flip playing
    time.sleep(9.0)
    stop_rec(outer, r2)
    mark("outer_stopped")

elif KIND == "jazz":
    # song 1 (final film): dilla x nujabes dig -> GPT lands -> finger drums bank A
    # -> KEYS chromatic notes -> AI PERFORM on
    r1 = start_rec(inner, "internal")
    T0 = time.time(); mark("T0")
    wait_until(T0 + 2.0)
    cmd("crate://dig?q=" + urllib.parse.quote("dilla drums x nujabes piano"))
    g = grid_from_play(T0, 90.0)
    mark("grid", t0=g.t0, bar=g.bar)
    gpt = wait_event(con, "gpt", T0, timeout=12)
    mark("gpt", ok=bool(gpt))
    tb = g.next_bar(time.time(), plus=1)
    wait_until(tb - 0.8)
    cmd("crate://bank?b=A")
    pat = [(0.0, 1), (0.5, 5), (1.0, 3), (1.5, 6), (2.0, 1), (2.75, 1), (3.0, 3), (3.5, 16),
           (4.0, 13), (4.5, 5), (5.0, 4), (5.5, 7), (6.0, 1), (6.5, 15), (7.0, 3), (7.25, 3), (7.5, 12)]
    mark("finger_start", t=tb)
    hits(g, tb, pat, lambda i: f"crate://pad?i={i}&b=A")
    tk = g.next_bar(time.time(), plus=0)
    wait_until(tk - 0.6)
    cmd("crate://mode?m=keys")
    mark("keys_start", t=tk)
    notes = [(0.0, 0), (1.0, 3), (1.5, 5), (2.5, 7), (3.5, 10), (4.0, 7), (4.5, 5), (5.0, 3),
             (6.0, 0), (6.5, 1), (7.0, 2), (7.5, 3)]
    hits(g, tk, notes, lambda s: f"crate://pad?i=13&b=A&semi={s}")
    tp = g.next_bar(time.time(), plus=0)
    wait_until(tp - 0.6)
    cmd("crate://mode?m=seq")
    cmd("crate://perform?on=1")
    mark("perform_start", t=tp)
    wait_until(tp + 4 * g.bar)
    stop_rec(inner, r1)
    mark("inner_stopped")

elif KIND == "song2":
    r1 = start_rec(inner, "internal")
    T0 = time.time(); mark("T0")
    wait_until(T0 + 4.0)                         # pre-roll: room for the typed prompt
    cmd("crate://dig?q=" + urllib.parse.quote("deep house, 124"))
    g = grid_from_play(T0, 124.0)
    mark("grid", t0=g.t0, bar=g.bar)
    # 2 bars of the groove, then KEYS chords for 2 bars
    tk = g.next_bar(time.time(), plus=1)
    wait_until(tk - 0.6)
    cmd("crate://mode?m=keys")
    time.sleep(0.2)
    cmd("crate://bank?b=C")
    cmd("crate://pad?i=2&b=C&v=1")               # select the keys one-shot (quiet)
    m7 = [0, 3, 7, 10]
    maj7 = [-4, 0, 3, 7]
    stabs = [(0.5, m7), (1.5, m7), (2.75, m7), (3.5, m7), (4.5, maj7), (5.5, maj7), (6.75, maj7), (7.5, maj7)]
    mark("keys_start", t=tk)
    for off, chord in stabs:
        wait_until(tk + off * g.beat - 0.05)
        with open(CMD, "a") as f:
            for semi in chord:
                f.write(f"crate://pad?i=2&b=C&semi={semi}\n")
        mark("stab", off=off, chord=chord)
    # PAD FX: pick the filter, then the build (hinge == FX amount), snap = DROP
    tf = g.next_bar(time.time(), plus=0)
    wait_until(tf - 0.8)
    cmd("crate://mode?m=padfx")
    time.sleep(0.4)
    cmd("crate://fx?t=lpf")
    tb = g.next_bar(time.time(), plus=1)        # build starts on a downbeat
    mark("build_start", t=tb, bars=BUILD_BARS)
    n = int(BUILD_BARS * g.bar / 0.1)
    for i in range(n + 1):
        wait_until(tb + i * 0.1)
        v = 0.95 * (i / n) ** 1.15
        with open(CMD, "a") as f:
            f.write(f"crate://fxamt?v={v:.3f}\n")
    t_drop = tb + BUILD_BARS * g.bar
    wait_until(t_drop - 0.05)
    cmd("crate://fxamt?v=0")
    mark("snap", t_target=t_drop)
    wait_until(t_drop + 4 * g.bar)
    stop_rec(inner, r1)
    mark("inner_stopped")

elif KIND == "dropback":
    cmd("crate://dig?q=" + urllib.parse.quote("deep house, 124"))
    g = grid_from_play(time.time() - 1, 124.0)
    cmd("crate://mode?m=padfx")
    cmd("crate://fx?t=lpf")
    r2 = start_rec(outer, "1")
    T0 = time.time(); mark("T0")
    tb = g.next_bar(time.time(), plus=1)
    n = int(2 * g.bar / 0.1)
    for i in range(n + 1):
        wait_until(tb + i * 0.1)
        with open(CMD, "a") as f:
            f.write(f"crate://fxamt?v={0.95 * i / n:.3f}\n")
    t_drop = tb + 2 * g.bar
    wait_until(t_drop - 0.05)
    cmd("crate://fxamt?v=0")
    mark("snap", t_target=t_drop)
    wait_until(t_drop + 3 * g.bar)
    stop_rec(outer, r2)

elif KIND == "paywall":
    cmd("crate://dig?q=" + urllib.parse.quote("deep house, 124"))
    time.sleep(3.0)
    r1 = start_rec(inner, "internal")
    T0 = time.time(); mark("T0")
    time.sleep(1.0)
    cmd("crate://paywall")
    time.sleep(7.0)
    stop_rec(inner, r1)

json.dump({"events": events}, open(os.path.join(CLIPS, f"{TAKE}_events.json"), "w"), indent=1)
print("done", flush=True)
