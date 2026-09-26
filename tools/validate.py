#!/usr/bin/env python3
import os
import json
import wave
import contextlib
from collections import Counter, defaultdict

LIB = "/Users/shuhanzhang/duo-hack/library"


def main():
    with open(os.path.join(LIB, "loops.json")) as f:
        idx = json.load(f)
    loops = idx["loops"]
    print(f"version={idx['version']} styles={idx['styles']}")
    print(f"total loops: {len(loops)}")

    errors = []
    total_bytes = 0
    bpms = []
    for e in loops:
        path = os.path.join(LIB, e["file"])
        if not os.path.isfile(path):
            errors.append(f"MISSING FILE {e['id']} {path}")
            continue
        size = os.path.getsize(path)
        total_bytes += size
        with contextlib.closing(wave.open(path, "r")) as w:
            frames = w.getnframes()
            rate = w.getframerate()
            sw = w.getsampwidth()
            ch = w.getnchannels()
        real_dur = frames / rate
        expected = e["bars"] * 240.0 / e["bpm"]
        diff_ms = abs(real_dur - expected) * 1000
        if diff_ms > 1.0:
            errors.append(f"DURATION MISMATCH {e['id']} diff={diff_ms:.3f}ms real={real_dur:.5f} expected={expected:.5f}")
        if rate != 44100 or sw != 2 or ch != 2:
            errors.append(f"FORMAT {e['id']} rate={rate} sw={sw} ch={ch}")
        if abs(real_dur - e["durationSec"]) > 0.002:
            errors.append(f"durationSec field mismatch {e['id']} json={e['durationSec']} real={real_dur:.5f}")
        if len(e["slices16Sec"]) != 16:
            errors.append(f"slices16Sec len!=16 {e['id']}")
        if len(e["beatsSec"]) != e["bars"] * e["beatsPerBar"]:
            errors.append(f"beatsSec len mismatch {e['id']}")
        for style, v in e["styles"].items():
            if not (0 <= v <= 1):
                errors.append(f"style out of range {e['id']} {style}={v}")
        if not (0 <= e["brightness"] <= 1):
            errors.append(f"brightness out of range {e['id']}")
        if not (0 <= e["dust"] <= 1):
            errors.append(f"dust out of range {e['id']}")
        if e["instrument"] == "break":
            if e["key"] is not None or e["chordsPerBar"] is not None or e["bassPerBeat"] is not None:
                errors.append(f"break should have null key/chords/bass {e['id']}")
        bpms.append(e["bpm"])

    print(f"\ntotal audio size: {total_bytes/1e6:.1f} MB")
    print(f"errors: {len(errors)}")
    for er in errors:
        print(" -", er)

    print("\n--- counts per instrument ---")
    print(Counter(e["instrument"] for e in loops))

    print("\n--- bpm range ---")
    print(f"min={min(bpms):.2f} max={max(bpms):.2f}")

    print("\n--- top style (argmax) distribution ---")
    top_style = Counter()
    for e in loops:
        top_style[max(e["styles"], key=e["styles"].get)] += 1
    print(top_style)

    print("\n--- with chordsPerBar (non-null list) ---")
    n_chords = sum(1 for e in loops if e["chordsPerBar"] is not None)
    n_bass = sum(1 for e in loops if e["bassPerBeat"] is not None)
    n_notes = sum(1 for e in loops if e["notes"] is not None)
    print(f"chordsPerBar: {n_chords}/{len(loops)}  bassPerBeat: {n_bass}/{len(loops)}  notes(transcribed): {n_notes}/{len(loops)}")

    print("\n--- moods distribution ---")
    mood_c = Counter()
    for e in loops:
        mood_c.update(e["moods"])
    print(mood_c)

    # candidates for "killer nujabes piano"
    print("\n--- top jazzhop-piano candidates (piano/keys, sorted by jazzhop+dilla score) ---")
    pk = [e for e in loops if e["instrument"] in ("piano", "keys") and e["styles"]["jazzhop"] >= 0.7]
    pk.sort(key=lambda e: -(e["styles"]["jazzhop"] + e["styles"]["dilla"]))
    for e in pk[:10]:
        print(f"  {e['id']} {e['name']:>9} jazzhop={e['styles']['jazzhop']} dilla={e['styles']['dilla']} key={e['key']} bpm={e['bpm']} src={e['source']}")

    print("\n--- top vintage break candidates ---")
    br = [e for e in loops if e["instrument"] == "break"]
    br.sort(key=lambda e: -(e["styles"]["vintage"] + e["styles"]["boombap"]))
    for e in br:
        print(f"  {e['id']} {e['name']:>9} vintage={e['styles']['vintage']} boombap={e['styles']['boombap']} bpm={e['bpm']} src={e['source']}")

    return len(errors)


if __name__ == "__main__":
    n = main()
    raise SystemExit(1 if n else 0)
