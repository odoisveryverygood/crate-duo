#!/usr/bin/env python3
"""Batched decode/process/analyze pass. Resumable: each call processes up to --n
not-yet-done items from selected.jsonl and appends to processed_meta.jsonl, so a
stall/interrupt never loses prior batches. Run with the forkdaw venv python:

  /Users/shuhanzhang/forkdaw/.venv/bin/python oneshots_ingest.py --n 100
"""
import sys
import os
import json
import hashlib
import argparse

sys.path.insert(0, os.path.dirname(__file__))
from oneshots_common import CATEGORY_MAX_LEN, DEFAULT_MAX_LEN, PITCHED_CATEGORIES, extract_root_from_filename  # noqa: E402
import oneshots_audio as audio_lib  # noqa: E402

SCRATCH = "/private/tmp/claude-503/-Users-shuhanzhang/e4350d56-7646-49d3-90c7-6512aef4989d/scratchpad"
SELECTED_FILE = os.path.join(SCRATCH, "selected.jsonl")
META_FILE = os.path.join(SCRATCH, "processed_meta.jsonl")
FAILED_FILE = os.path.join(SCRATCH, "failed.jsonl")
WAV_DIR = os.path.join(SCRATCH, "processed_wavs")
TMP_DECODE = os.path.join(SCRATCH, "_decode_tmp.wav")


def clip01(x):
    return max(0.0, min(1.0, x))


def uid_for(path):
    return hashlib.md5(path.encode("utf-8")).hexdigest()[:16]


def load_done():
    done = set()
    for fn in (META_FILE, FAILED_FILE):
        if os.path.exists(fn):
            with open(fn) as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        done.add(json.loads(line)["path"])
                    except Exception:
                        pass
    return done


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=100)
    args = ap.parse_args()

    os.makedirs(WAV_DIR, exist_ok=True)
    rows = [json.loads(l) for l in open(SELECTED_FILE)]
    done = load_done()
    remaining = [r for r in rows if r["path"] not in done]
    print(f"selected={len(rows)} already_done={len(done)} remaining={len(remaining)}", file=sys.stderr)
    batch = remaining[: args.n]
    if not batch:
        print("nothing left to ingest.", file=sys.stderr)
        return

    meta_f = open(META_FILE, "a")
    failed_f = open(FAILED_FILE, "a")
    n_ok = n_fail = 0
    for i, row in enumerate(batch):
        if i % 10 == 0:
            print(f"  [{i}/{len(batch)}] {row['category']:8s} {os.path.basename(row['path'])[:50]}", file=sys.stderr)
        cat = row["category"]
        max_len = CATEGORY_MAX_LEN.get(cat, DEFAULT_MAX_LEN)
        try:
            data, sr = audio_lib.decode(row["path"], TMP_DECODE)
            out, ok = audio_lib.process(data, sr, max_len)
            if not ok or out.shape[0] < int(0.02 * sr):
                raise audio_lib.DecodeError("silent or too short after trim")
            feat = audio_lib.analyze(out, sr)
        except Exception as e:
            n_fail += 1
            failed_f.write(json.dumps({"path": row["path"], "reason": str(e)[:200]}) + "\n")
            continue

        ctx = row["styles"]
        dust_pack_hint = max(ctx.get("vintage", 0), ctx.get("lofi", 0), ctx.get("dilla", 0))
        muffled = clip01(1.0 - feat["rolloff_hz"] / 9000.0)
        noise = clip01(feat["flatness"] * 4.0)
        dust = clip01(0.35 * muffled + 0.25 * noise + 0.40 * dust_pack_hint)

        rootnote, key = None, None
        if cat in PITCHED_CATEGORIES:
            rootnote, key = extract_root_from_filename(os.path.basename(row["path"]), cat)
            if rootnote is None:
                try:
                    rootnote = audio_lib.pitch_from_audio(out, sr)
                except Exception:
                    rootnote = None

        uid = uid_for(row["path"])
        wav_path = os.path.join(WAV_DIR, uid + ".wav")
        import soundfile as sf
        sf.write(wav_path, out, sr, subtype="PCM_16")

        meta_f.write(json.dumps({
            "path": row["path"], "root": row["root"], "pack": row["pack"],
            "rel_in_root": row["rel_in_root"], "category": cat, "tier": row["tier"],
            "styles": row["styles"], "reserved": row.get("reserved", False),
            "uid": uid, "wav": wav_path, "sr": sr,
            "durationSec": feat["durationSec"], "decaySec": feat["decaySec"],
            "centroid_hz": feat["centroid_hz"], "crest_db": feat["crest_db"],
            "attack_ms": feat["attack_ms"], "flatness": feat["flatness"],
            "dust": round(dust, 3), "rootNote": rootnote, "key": key,
            "sustained": feat["sustained"],
        }) + "\n")
        n_ok += 1
    meta_f.close()
    failed_f.close()
    print(f"batch done: ok={n_ok} fail={n_fail}  remaining_after={len(remaining) - len(batch)}", file=sys.stderr)


if __name__ == "__main__":
    main()
