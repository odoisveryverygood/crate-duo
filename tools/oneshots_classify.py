#!/usr/bin/env python3
"""Pass 1: classify every candidate audio file under the source roots (no audio I/O).

Reads the null-separated file list built by `find`, classifies each path into a
category + loop_like + tier + style-context scores, and writes one JSON object per
line to candidates.jsonl. Fast (string ops only) so it can run over all ~77k files.
"""
import sys
import os
import json

sys.path.insert(0, os.path.dirname(__file__))
from oneshots_common import (  # noqa: E402
    DOCS, root_and_rel, pack_name, tier_for, norm, classify_category,
    is_loop_like, is_junk, context_style_scores, LOOP_EXEMPT_CATEGORIES, STYLES,
)

SCRATCH = "/private/tmp/claude-503/-Users-shuhanzhang/e4350d56-7646-49d3-90c7-6512aef4989d/scratchpad"
LIST_FILE = os.path.join(SCRATCH, "all_audio_files.nul")
OUT_FILE = os.path.join(SCRATCH, "candidates.jsonl")


def main():
    with open(LIST_FILE, "rb") as f:
        data = f.read()
    raw_paths = [p for p in data.split(b"\x00") if p]

    rows = []
    n_junk = 0
    n_unclassified = 0
    n_loop_excluded = 0
    for rp in raw_paths:
        try:
            rel_path = rp.decode("utf-8")
        except UnicodeDecodeError:
            rel_path = rp.decode("utf-8", errors="replace")
        root, rel_in_root = root_and_rel(rel_path)
        if root is None:
            continue
        path = os.path.join(DOCS, rel_path)
        pack = pack_name(root, rel_in_root)
        full_norm = norm(f"{root}/{rel_in_root}")
        if is_junk(full_norm):
            n_junk += 1
            continue
        basename_norm = norm(os.path.basename(rel_in_root))
        category = classify_category(basename_norm) or classify_category(full_norm)
        if category is None:
            n_unclassified += 1
            continue
        segs_norm = [norm(s) for s in (root + "/" + rel_in_root).split("/") if s]
        loop_like = is_loop_like(segs_norm)
        if loop_like and category not in LOOP_EXEMPT_CATEGORIES:
            n_loop_excluded += 1
            continue
        tier = tier_for(root, rel_in_root)
        styles = context_style_scores(full_norm)
        try:
            size = os.path.getsize(path)
        except OSError:
            size = 0
        rows.append({
            "path": path,
            "root": root,
            "pack": pack,
            "rel_in_root": rel_in_root,
            "category": category,
            "loop_like": loop_like,
            "tier": tier,
            "styles": styles,
            "size": size,
            "ext": os.path.splitext(path)[1].lower(),
        })

    with open(OUT_FILE, "w") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")

    print(f"total raw paths: {len(raw_paths)}", file=sys.stderr)
    print(f"junk excluded: {n_junk}", file=sys.stderr)
    print(f"unclassified (no category match): {n_unclassified}", file=sys.stderr)
    print(f"loop-like excluded: {n_loop_excluded}", file=sys.stderr)
    print(f"kept candidates: {len(rows)}", file=sys.stderr)
    print(f"wrote {OUT_FILE}", file=sys.stderr)

    # summary by category / tier / root
    from collections import Counter
    cat_counts = Counter(r["category"] for r in rows)
    print("\n-- category counts (tier1+2) --", file=sys.stderr)
    for cat, cnt in sorted(cat_counts.items(), key=lambda x: -x[1]):
        tier1 = sum(1 for r in rows if r["category"] == cat and r["tier"] == 1)
        print(f"  {cat:10s} total={cnt:6d}  tier1={tier1:6d}", file=sys.stderr)

    root_counts = Counter(r["root"] for r in rows)
    print("\n-- root counts --", file=sys.stderr)
    for root, cnt in root_counts.items():
        print(f"  {root:25s} {cnt}", file=sys.stderr)


if __name__ == "__main__":
    main()
