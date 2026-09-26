#!/usr/bin/env python3
import json
import os

LIB = "/Users/shuhanzhang/duo-hack/library"

with open(os.path.join(LIB, "loops.json")) as f:
    idx = json.load(f)

loops = idx["loops"]
order = ["piano", "rhodes", "keys", "guitar", "strings", "pad", "vibes", "horns", "sax", "flute", "break"]
loops_sorted = sorted(loops, key=lambda e: (order.index(e["instrument"]) if e["instrument"] in order else 99, e["id"]))

lines = []
lines.append("# Melodic Loop Library")
lines.append("")
lines.append(f"{len(loops)} loops, {sum(1 for e in loops if e['instrument']!='break')} melodic + {sum(1 for e in loops if e['instrument']=='break')} drum breaks. "
             f"BPM range {min(e['bpm'] for e in loops):.0f}-{max(e['bpm'] for e in loops):.0f}. "
             "Audio: 44.1kHz/16-bit stereo WAV, -14 LUFS integrated, trimmed to exact bar loops with 5ms fades.")
lines.append("")
lines.append("| id | name | instrument | bpm | bars | key | top styles | moods | source |")
lines.append("|---|---|---|---|---|---|---|---|---|")
for e in loops_sorted:
    top2 = sorted(e["styles"].items(), key=lambda kv: -kv[1])[:2]
    top2s = ", ".join(f"{k} {v:.2f}" for k, v in top2)
    moods = ", ".join(e["moods"])
    key = e["key"] if e["key"] else "-"
    src = e["source"]
    bpm = e["bpm"]
    bpm_s = f"{bpm:.0f}" if bpm == int(bpm) else f"{bpm:.2f}"
    lines.append(f"| {e['id']} | {e['name']} | {e['instrument']} | {bpm_s} | {e['bars']} | {key} | {top2s} | {moods} | {src} |")

with open(os.path.join(LIB, "LOOPS.md"), "w") as f:
    f.write("\n".join(lines) + "\n")

print("wrote LOOPS.md with", len(loops), "rows")
