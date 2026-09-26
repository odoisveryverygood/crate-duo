#!/usr/bin/env python3
"""Scan source sample-pack directories for candidate melodic loops / drum breaks.

Read-only: never writes into ~/Documents. Prints a grouped report and can dump
a JSON candidate list to the scratchpad for the curation step.
"""
import os
import re
import sys
import json
import argparse
import subprocess

DOCS = os.path.expanduser("~/Documents")

ROOTS = [
    os.path.join(DOCS, "Jazz Hop合集"),
    os.path.join(DOCS, "LofiHiphop超值合集"),
    os.path.join(DOCS, "cymatics", "Cymatics - Lofi Starter Pack"),
    os.path.join(DOCS, "cymatics", "Cymatics - House Starter Pack"),
    os.path.join(DOCS, "cymatics", "Cymatics - Cobra Hip Hop Sample Pack"),
    os.path.join(DOCS, "cymatics", "Cymatics - Eternity Sample Pack"),
    os.path.join(DOCS, "cymatics", "Cymatics - Oracle Sample Pack"),
]

AUDIO_EXT = {".wav", ".aif", ".aiff", ".mp3"}

# directory-name substrings that mean "skip this whole subtree"
DIR_EXCLUDE = re.compile(
    r"one[\s_-]?shot|one[\s_-]?shots|midi|_fx\b|^fx$|/fx/|vocal|preset|serum|massive|"
    r"artwork|cover|demo|\.nfo|kick|snare|hihat|hi-hat|hi_hat|clap|cymbal|snap\b|"
    r"808|whitenoise|white noise|foley|ambient|riser|impact|nfo",
    re.I,
)

MELODIC_DIR_INCLUDE = re.compile(
    r"melod|piano|keys?|rhodes|e-?piano|guitar|string|pad\b|pads|vibes|horn|sax|flute|"
    r"woodwind|brass|chord|stab|synth|gliss|resample|loop_stem|loop stems|song_starter",
    re.I,
)

BREAK_DIR_INCLUDE = re.compile(
    r"drum.?loop|live_drum|drums$|drums/|break|full.?loop|full_loop|full drum",
    re.I,
)

BREAK_DIR_EXCLUDE = re.compile(
    r"perc(ussion)?[\s_-]?loop|hihat|hi-hat|top drum|drum fill|buildup|build-up",
    re.I,
)


def iter_candidates(mode):
    """mode: 'melodic' or 'break'"""
    for root in ROOTS:
        if not os.path.isdir(root):
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            rel_dir = dirpath[len(DOCS):].lstrip("/")
            if DIR_EXCLUDE.search(rel_dir):
                dirnames[:] = []
                continue
            if mode == "melodic":
                ok_dir = bool(MELODIC_DIR_INCLUDE.search(rel_dir))
            else:
                ok_dir = bool(BREAK_DIR_INCLUDE.search(rel_dir)) and not BREAK_DIR_EXCLUDE.search(rel_dir)
            if not ok_dir:
                continue
            for fn in filenames:
                ext = os.path.splitext(fn)[1].lower()
                if ext not in AUDIO_EXT:
                    continue
                if DIR_EXCLUDE.search(fn):
                    continue
                full = os.path.join(dirpath, fn)
                yield full


def parse_bpm_key(name):
    bpm = None
    m = re.search(r"(\d{2,3})\s*bpm", name, re.I)
    if m:
        bpm = int(m.group(1))
    key = None
    m = re.search(r"key[_\s-]*([A-G])(#|b)?(m|min|maj)?\b", name, re.I)
    if m:
        key = m.group(0)
    else:
        m = re.search(r"[_\s\(-]([A-G])(#|b)?(m|min)\b", name)
        if m:
            key = m.group(0).strip("_ (-")
    return bpm, key


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", choices=["melodic", "break"], default="melodic")
    ap.add_argument("--out", default=None)
    ap.add_argument("--grep", default=None, help="only paths containing this (case-insens)")
    args = ap.parse_args()

    rows = []
    for full in iter_candidates(args.mode):
        rel = full[len(DOCS):].lstrip("/")
        if args.grep and args.grep.lower() not in rel.lower():
            continue
        bpm, key = parse_bpm_key(os.path.basename(full))
        try:
            size = os.path.getsize(full)
        except OSError:
            size = 0
        rows.append({"path": full, "rel": rel, "bpm": bpm, "key": key, "size": size})

    rows.sort(key=lambda r: r["rel"])
    print(f"# {args.mode} candidates: {len(rows)}", file=sys.stderr)
    for r in rows:
        print(f"{r['bpm'] or '?':>4} {r['key'] or '?':>5}  {r['rel']}")

    if args.out:
        with open(args.out, "w") as f:
            json.dump(rows, f, indent=1)
        print(f"wrote {args.out}", file=sys.stderr)


if __name__ == "__main__":
    main()
