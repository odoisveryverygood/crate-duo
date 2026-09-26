#!/usr/bin/env python3
"""Pass 2: select which candidates actually get processed into audio.

Reads candidates.jsonl (metadata only, no audio decode yet). For every (style,
category) coverage rule in the spec, reserves enough top-scoring candidates to
guarantee the ONESHOTS.md coverage table will pass. Then fills each category up to
~1.15x its target count (buffer for later QC drops) via pack-round-robin, tier1
sources preferred, for general diversity. Writes selected.jsonl.
"""
import sys
import os
import json
import re
import math
import random
import collections

sys.path.insert(0, os.path.dirname(__file__))
from oneshots_common import STYLES, CATEGORY_TARGETS  # noqa: E402

SCRATCH = "/private/tmp/claude-503/-Users-shuhanzhang/e4350d56-7646-49d3-90c7-6512aef4989d/scratchpad"
IN_FILE = os.path.join(SCRATCH, "candidates.jsonl")
OUT_FILE = os.path.join(SCRATCH, "selected.jsonl")

RNG_SEED = 20260926
THRESH = 0.6

_RATE_SUFFIX_RE = re.compile(r"[\s_\-]*(48k|44k|441|24bit|16bit|32bit|master|final|mix ?down|copy|v2|hq|resampled)$")


def dedup_key(rec):
    stem = os.path.splitext(os.path.basename(rec["rel_in_root"]))[0].lower()
    stem = re.sub(r"[\s_\-]+", " ", stem).strip()
    prev = None
    while prev != stem:
        prev = stem
        stem = _RATE_SUFFIX_RE.sub("", stem).strip()
    return (rec["pack"], rec["category"], stem)


def load():
    with open(IN_FILE) as f:
        return [json.loads(l) for l in f]


def dedup(rows):
    seen = {}
    for r in rows:
        k = dedup_key(r)
        cur = seen.get(k)
        if cur is None:
            seen[k] = r
        else:
            # prefer the one without a rate/suffix tag (shorter normalized survives via
            # dedup_key already; between true ties prefer larger file = likely higher quality)
            if r["size"] > cur["size"]:
                seen[k] = r
    return list(seen.values())


def main():
    random.seed(RNG_SEED)
    rows = load()
    print(f"loaded {len(rows)} candidates", file=sys.stderr)
    rows = dedup(rows)
    print(f"after dedup: {len(rows)}", file=sys.stderr)

    by_category = collections.defaultdict(list)
    for r in rows:
        by_category[r["category"]].append(r)

    reserved = {}  # path -> row

    def qualifying_count(cats, style):
        return sum(1 for r in reserved.values() if r["category"] in cats and r["styles"].get(style, 0) >= THRESH)

    def top_up(cats, style, min_count):
        have = qualifying_count(cats, style)
        if have >= min_count:
            return
        need = min_count - have
        pool = [r for r in rows
                if r["category"] in cats and r["path"] not in reserved and r["styles"].get(style, 0) >= THRESH]
        pool.sort(key=lambda r: (r["tier"], -r["styles"][style], r["path"]))
        for r in pool[:need]:
            reserved[r["path"]] = r

    for style in STYLES:
        top_up(["kick"], style, 5)
        hat_min = 10 if style in ("trap", "drill") else 5
        top_up(["hat"], style, hat_min)
        top_up(["snare", "clap"], style, 5)
        if style == "house":
            top_up(["clap"], style, 5)
            top_up(["openhat"], style, 5)
        else:
            top_up(["openhat"], style, 2)
        top_up(["perc"], style, 2)
        top_up(["fx"], style, 2)
        if style in ("trap", "drill"):
            top_up(["808"], style, 8)

    print(f"reserved (coverage-guaranteed) candidates: {len(reserved)}", file=sys.stderr)
    res_by_cat = collections.Counter(r["category"] for r in reserved.values())
    for cat, cnt in sorted(res_by_cat.items()):
        print(f"  reserved[{cat}] = {cnt}", file=sys.stderr)

    selected = dict(reserved)  # path -> row

    for cat, target in CATEGORY_TARGETS.items():
        want_total = math.ceil(target * 1.15) + 3
        have = [r for r in selected.values() if r["category"] == cat]
        need = want_total - len(have)
        if need <= 0:
            continue
        pool = [r for r in by_category.get(cat, []) if r["path"] not in selected]
        # tier1 first, then tier2, round-robin by pack within each tier for diversity
        for tier in (1, 2):
            if need <= 0:
                break
            tier_pool = [r for r in pool if r["tier"] == tier]
            by_pack = collections.defaultdict(list)
            for r in tier_pool:
                by_pack[r["pack"]].append(r)
            for plist in by_pack.values():
                random.shuffle(plist)
            pack_names = list(by_pack.keys())
            random.shuffle(pack_names)
            idx = 0
            guard = 0
            while need > 0 and any(by_pack[p] for p in pack_names) and guard < 200000:
                guard += 1
                p = pack_names[idx % len(pack_names)]
                idx += 1
                if by_pack[p]:
                    r = by_pack[p].pop()
                    selected[r["path"]] = r
                    need -= 1

    print(f"total selected: {len(selected)}", file=sys.stderr)
    sel_by_cat = collections.Counter(r["category"] for r in selected.values())
    for cat, target in CATEGORY_TARGETS.items():
        print(f"  {cat:10s} selected={sel_by_cat.get(cat,0):4d}  target={target:4d}", file=sys.stderr)

    with open(OUT_FILE, "w") as f:
        for r in selected.values():
            r = dict(r)
            r["reserved"] = r["path"] in reserved
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    print(f"wrote {OUT_FILE}", file=sys.stderr)


if __name__ == "__main__":
    main()
