#!/usr/bin/env python3
"""Analyze a CRATE self-test run: console events + marks + recorded master output. Prints PASS/FAIL per check."""
import json, sys, os
import numpy as np

out = sys.argv[1]
offline = out.endswith("-offline")
events, marks = [], {}
for line in open(os.path.join(out, "console.log"), errors="ignore"):
    i = line.find("CRATE {")
    if i >= 0:
        try: events.append(json.loads(line[i + 6:]))
        except Exception: pass
if os.path.exists(os.path.join(out, "marks.jsonl")):
    for line in open(os.path.join(out, "marks.jsonl")):
        m = json.loads(line); marks[m["name"]] = m["t"]

def ev(name, after=None, before=None):
    return [e for e in events if e.get("event") == name
            and (after is None or e["t"] >= after) and (before is None or e["t"] <= before)]

results = []
def check(name, ok, detail=""):
    results.append((name, "PASS" if ok is True else ("SKIP" if ok is None else "FAIL"), detail))

launch = ev("launch")
check("launch: library readable", bool(launch) and launch[0].get("libraryReadable"), str(launch[0].get("library") if launch else "no launch event"))
d1, d2, fold, snap = (marks.get(k) for k in ("dig1", "dig2", "fold", "snap"))
keys_t, perf_t, end_t = marks.get("keys"), marks.get("perform"), marks.get("end")

# --- DIG 1: Dilla x Nujabes
jp = ev("jev_plan", d1, d2)
if offline: check("dig1: jev plan", None, "offline")
else:
    j = jp[0] if jp else {}
    check("dig1: jev plan < 600 ms", bool(jp) and j.get("ms", 9e9) < 600, f"{j.get('ms')} ms")
    check("dig1: jev understood (dilla / jazzhop / piano)", j.get("drum_style") == "dilla" and j.get("sample_style") == "jazzhop" and j.get("instrument") in ("piano", "rhodes", "keys"),
          f"{j.get('scope')} {j.get('drum_style')} {j.get('sample_style')} {j.get('instrument')} bars={j.get('bars')}")
kit1 = ev("kit", d1, d2); loop1 = ev("loop", d1, d2)
check("dig1: dilla kit loaded", bool(kit1) and kit1[0].get("style") == "dilla", str(kit1[0] if kit1 else "none")[:120])
check("dig1: piano loop chosen", bool(loop1), str(loop1[0] if loop1 else "none")[:120])
g1 = ev("gpt", d1, d2)
if offline: check("dig1: gpt arrangement", None, "offline")
else: check("dig1: gpt arrangement ok < 6 s", bool(g1) and g1[0].get("ok") and g1[0].get("ms", 9e9) < 6000, str(g1[0] if g1 else "none")[:120])
# --- DIG 2: house drums
kit2 = ev("kit", d2, fold)
check("dig2: house kit swapped", bool(kit2) and kit2[0].get("style") == "house", str(kit2[0] if kit2 else "none")[:120])
# --- hinge / drop / keys / perform
check("hinge: drop fired on snap", bool(ev("drop", snap - 1.5 if snap else None, (snap or 0) + 2.5)), f"{len(ev('drop'))} drop events")
kp = [e for e in ev("pad", keys_t, perf_t) if e.get("semi", 0) != 0]
check("keys: chromatic notes played", len(kp) >= 5, f"{len(kp)} pitched hits")
if offline: check("perform: jev fills", None, "offline")
else:
    pf = ev("perform", perf_t, end_t)
    check("perform: jev decided per bar", len(pf) >= 2, f"{len(pf)} decisions: {[p.get('fill') for p in pf][:6]}")
errs = ev("error")
check("no error events", not errs, "; ".join(str(e)[:80] for e in errs[:3]))

# --- audio
wav = os.path.join(out, "crate-debug.wav")
start = ev("engine_start")
if not os.path.exists(wav) or not start:
    check("audio: recording present", False, "missing wav or engine_start")
else:
    import librosa
    y, sr = librosa.load(wav, sr=None, mono=True)
    t0 = start[0]["t"]
    def seg(a, b):
        a = max(0, int((a - t0) * sr)); b = min(len(y), int((b - t0) * sr))
        return y[a:b] if b > a else np.zeros(1)
    def db(x): return 20 * np.log10(max(1e-9, float(np.sqrt(np.mean(x ** 2)))))
    def centroid(x): return float(np.median(librosa.feature.spectral_centroid(y=x, sr=sr))) if len(x) > 2048 else 0
    peak = float(np.max(np.abs(y))) if len(y) else 0
    check("audio: recording present", len(y) > sr * 5, f"{len(y)/sr:.1f} s @ {sr} Hz")
    check("audio: no clipping (peak < -0.3 dBFS)", 20 * np.log10(max(peak, 1e-9)) < -0.3, f"peak {20*np.log10(max(peak,1e-9)):.1f} dBFS")
    s1 = seg(d1 + 2, d2) if d1 and d2 else np.zeros(1)
    check("audio: dig1 section is playing (> -40 dBFS)", db(s1) > -40, f"{db(s1):.1f} dBFS")
    if loop1 and len(s1) > sr * 3:
        bpm = float(loop1[0].get("bpm", 0))
        tempo = float(np.atleast_1d(librosa.beat.beat_track(y=s1, sr=sr)[0])[0])
        ok = any(abs(tempo * f - bpm) <= 3 for f in (1, 2, 0.5))
        check("audio: tempo matches loop bpm", ok, f"detected {tempo:.1f} vs loop {bpm}")
    ref = seg(d2 + 2, fold) if d2 and fold else np.zeros(1)
    folded = seg(fold + 1.8, snap - 0.1) if fold and snap else np.zeros(1)
    after = seg(snap + 0.35, snap + 2.5) if snap else np.zeros(1)
    cr, cf, ca = centroid(ref), centroid(folded), centroid(after)
    check("hinge: fold closes the filter (centroid -60%)", cr > 0 and cf < 0.4 * cr, f"ref {cr:.0f} Hz → folded {cf:.0f} Hz")
    check("hinge: snap restores within 350 ms", cr > 0 and ca > 0.7 * cr, f"after snap {ca:.0f} Hz")

w = max(len(r[0]) for r in results)
for n, s, d in results:
    print(f"{s:4}  {n.ljust(w)}  {d}")
fails = sum(1 for r in results if r[1] == "FAIL")
print(f"\n{len(results) - fails}/{len(results)} passed" + (" — ALL GREEN" if fails == 0 else ""))
sys.exit(1 if fails else 0)
