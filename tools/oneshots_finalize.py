#!/usr/bin/env python3
"""Assemble library/oneshots.json + final WAVs from everything in processed_meta.jsonl
so far. Safe to re-run after every ingest batch (it fully rebuilds the output from the
checkpointed intermediate data, so it converges to the final library as batches land).
"""
import sys
import os
import json
import math
import shutil

sys.path.insert(0, os.path.dirname(__file__))
from oneshots_common import (  # noqa: E402
    STYLES, STYLE_KIT_TARGET, CATEGORY_TARGETS, CATEGORY_ID_PREFIX, LIBRARY, midi_to_name,
)

SCRATCH = "/private/tmp/claude-503/-Users-shuhanzhang/e4350d56-7646-49d3-90c7-6512aef4989d/scratchpad"
META_FILE = os.path.join(SCRATCH, "processed_meta.jsonl")
ONESHOTS_DIR = os.path.join(LIBRARY, "oneshots")
OUT_JSON = os.path.join(LIBRARY, "oneshots.json")
SQRT2 = math.sqrt(2)


def clip01(x):
    return max(0.0, min(1.0, x))


def minmax_norm(values):
    if not values:
        return []
    lo, hi = min(values), max(values)
    if hi - lo < 1e-9:
        return [0.5 for _ in values]
    return [clip01((v - lo) / (hi - lo)) for v in values]


TAG_RULES = [
    (lambda f: f["dust"] >= 0.7, "dusty"),
    (lambda f: f["dust"] >= 0.55, "vinyl"),
    (lambda f: f["dust"] < 0.25, "clean"),
    (lambda f: f["punch"] >= 0.75, "punchy"),
    (lambda f: f["punch"] >= 0.6, "tight"),
    (lambda f: f["punch"] < 0.3, "soft"),
    (lambda f: f["brightness"] >= 0.75, "crisp"),
    (lambda f: f["brightness"] >= 0.6, "bright"),
    (lambda f: f["brightness"] < 0.3, "warm"),
    (lambda f: f["brightness"] < 0.18, "muffled"),
    (lambda f: f["decaySec"] >= 0.6 and f["category"] in ("kick", "808", "cymbal"), "boomy"),
    (lambda f: f["decaySec"] >= 0.5 and f["category"] == "cymbal", "ringy"),
    (lambda f: f["decaySec"] < 0.12, "dry"),
    (lambda f: f["durationSec"] < 0.08, "snappy"),
    (lambda f: f["ctx_vintage"] >= 0.6 and f["category"] in ("kick", "snare", "hat", "perc"), "SP-1200"),
    (lambda f: f["ctx_house"] >= 0.6, "club"),
    (lambda f: f["ctx_trap"] >= 0.6 or f["ctx_drill"] >= 0.6, "hard"),
    (lambda f: f["flatness"] >= 0.35, "noisy"),
    (lambda f: f["tier"] == 1 and f["ctx_dilla"] >= 0.6, "wonky"),
    (lambda f: f["category"] == "rim", "woody"),
    (lambda f: f["category"] == "shaker", "loose"),
]
CATEGORY_BASE_TAG = {
    "kick": "kick", "snare": "snare", "clap": "clap", "hat": "hat", "openhat": "open hat",
    "rim": "rim", "perc": "perc", "shaker": "shaker", "cymbal": "cymbal", "808": "808",
    "bass": "bass", "fx": "fx", "vocal": "vocal chop", "texture": "texture", "keys": "keys",
    "synth": "synth",
}


def build_tags(feats):
    tags = []
    for pred, tag in TAG_RULES:
        try:
            if pred(feats) and tag not in tags:
                tags.append(tag)
        except Exception:
            pass
        if len(tags) >= 5:
            break
    base = CATEGORY_BASE_TAG.get(feats["category"])
    if base and base not in tags:
        tags.append(base)
    if len(tags) < 3:
        for extra in ("live", "roomy", "raw"):
            if len(tags) >= 3:
                break
            if extra not in tags:
                tags.append(extra)
    return tags[:6]


CAT_ABBR = {
    "kick": "KCK", "snare": "SNR", "clap": "CLP", "hat": "HAT", "openhat": "OHAT",
    "rim": "RIM", "perc": "PERC", "shaker": "SHK", "cymbal": "CYM", "808": "808",
    "bass": "BASS", "fx": "FX", "vocal": "VOX", "texture": "TEX", "keys": "KEY", "synth": "SYN",
}
DESC_CODES = [
    ("dusty", "DUST"), ("vinyl", "VNYL"), ("clean", "CLN"), ("punchy", "PNCH"),
    ("tight", "TITE"), ("soft", "SOFT"), ("crisp", "CRSP"), ("bright", "BRT"),
    ("warm", "WARM"), ("muffled", "MUTE"), ("boomy", "BOOM"), ("ringy", "RING"),
    ("dry", "DRY"), ("snappy", "SNAP"), ("SP-1200", "SP12"), ("club", "CLUB"),
    ("hard", "HARD"), ("noisy", "NSY"), ("wonky", "WNKY"), ("woody", "WOOD"),
    ("loose", "LOOS"), ("live", "LIVE"), ("roomy", "ROOM"), ("raw", "RAW"),
]


def build_name(feats, rootnote_pc, idx):
    cat = feats["category"]
    abbr = CAT_ABBR.get(cat, cat[:4].upper())
    if rootnote_pc:
        cand = f"{abbr} {rootnote_pc}".upper()
        if len(cand) <= 8:
            return cand
    for tag, code in DESC_CODES:
        if tag in feats["tags"]:
            budget = 8 - 1 - len(abbr)
            if len(code) <= budget:
                return f"{code} {abbr}"
    return f"{abbr} {idx:03d}"[:8]


def main():
    if not os.path.exists(META_FILE):
        print("no processed_meta.jsonl yet.", file=sys.stderr)
        return
    items = [json.loads(l) for l in open(META_FILE)]
    print(f"loaded {len(items)} processed items", file=sys.stderr)

    by_cat = {}
    for it in items:
        by_cat.setdefault(it["category"], []).append(it)

    for cat, its in by_cat.items():
        centroids = [it["centroid_hz"] for it in its]
        bright_norm = minmax_norm(centroids)
        punch_raw = [it["crest_db"] - 0.02 * it["attack_ms"] for it in its]
        punch_norm = minmax_norm(punch_raw)
        for it, b, pu in zip(its, bright_norm, punch_norm):
            it["brightness"] = round(b, 3)
            it["punch"] = round(pu, 3)

    for it in items:
        ctx = it["styles"]
        final_styles = {}
        for style in STYLES:
            tgt = STYLE_KIT_TARGET[style]
            dist = math.sqrt((it["dust"] - tgt["dust"]) ** 2 + (it["brightness"] - tgt["brightness"]) ** 2)
            closeness = 1.0 - min(1.0, dist / SQRT2)
            adj = 0.12 * (closeness - 0.5)
            final_styles[style] = round(clip01(ctx.get(style, 0.0) + adj), 3)
        it["final_styles"] = final_styles

    kept = []
    for cat, its in by_cat.items():
        target = CATEGORY_TARGETS.get(cat, len(its))
        if len(its) <= target:
            kept.extend(its)
            continue
        reserved_items = [it for it in its if it.get("reserved")]
        fill_items = [it for it in its if not it.get("reserved")]
        fill_items.sort(key=lambda it: -max(it["final_styles"].values()))
        n_fill = max(0, target - len(reserved_items))
        chosen = reserved_items + fill_items[:n_fill]
        if len(chosen) > target:
            chosen = chosen[:target]
        kept.extend(chosen)

    kept.sort(key=lambda it: (it["category"], it["pack"], it["rel_in_root"]))

    if os.path.isdir(ONESHOTS_DIR):
        shutil.rmtree(ONESHOTS_DIR)
    os.makedirs(ONESHOTS_DIR, exist_ok=True)

    per_cat_idx = {}
    samples = []
    for it in kept:
        cat = it["category"]
        per_cat_idx[cat] = per_cat_idx.get(cat, 0) + 1
        idx = per_cat_idx[cat]
        prefix, width = CATEGORY_ID_PREFIX[cat]
        sid = f"{prefix}{idx:0{width}d}"
        cat_dir = os.path.join(ONESHOTS_DIR, cat)
        os.makedirs(cat_dir, exist_ok=True)
        fname = f"{sid}.wav"
        out_path = os.path.join(cat_dir, fname)
        shutil.copyfile(it["wav"], out_path)

        feats_for_tags = {
            "dust": it["dust"], "punch": it["punch"], "brightness": it["brightness"],
            "decaySec": it["decaySec"], "durationSec": it["durationSec"], "category": cat,
            "flatness": it["flatness"], "tier": it["tier"],
            "ctx_vintage": it["styles"].get("vintage", 0), "ctx_house": it["styles"].get("house", 0),
            "ctx_trap": it["styles"].get("trap", 0), "ctx_drill": it["styles"].get("drill", 0),
            "ctx_dilla": it["styles"].get("dilla", 0),
        }
        tags = build_tags(feats_for_tags)
        rootnote_name = midi_to_name(it["rootNote"]) if it["rootNote"] is not None else None
        rootnote_pc = rootnote_name.rstrip("-0123456789") if rootnote_name else None
        name = build_name({**feats_for_tags, "tags": tags}, rootnote_pc, idx)

        loopable = bool(it.get("sustained")) if cat == "texture" else False
        source_rel = os.path.join(it["root"], it["rel_in_root"])
        samples.append({
            "id": sid,
            "file": f"oneshots/{cat}/{fname}",
            "name": name,
            "category": cat,
            "styles": it["final_styles"],
            "tags": tags,
            "brightness": it["brightness"],
            "punch": it["punch"],
            "dust": it["dust"],
            "decaySec": round(it["decaySec"], 3),
            "durationSec": round(it["durationSec"], 3),
            "rootNote": it["rootNote"],
            "key": it["key"],
            "loopable": loopable,
            "source": source_rel,
        })

    index = {
        "version": 1,
        "styles": STYLES,
        "categories": list(CATEGORY_TARGETS.keys()),
        "samples": samples,
    }
    with open(OUT_JSON, "w") as f:
        json.dump(index, f, ensure_ascii=False, indent=1)
    print(f"wrote {OUT_JSON} with {len(samples)} samples", file=sys.stderr)

    counts = {}
    for s in samples:
        counts[s["category"]] = counts.get(s["category"], 0) + 1
    for cat, target in CATEGORY_TARGETS.items():
        print(f"  {cat:10s} {counts.get(cat,0):4d} / {target:4d}", file=sys.stderr)


if __name__ == "__main__":
    main()
