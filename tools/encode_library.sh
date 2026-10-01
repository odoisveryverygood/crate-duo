#!/bin/bash
# The app bundles the sample library as AAC (256 kbps) in CAF: ~/duo-hack/library (WAV, the source of truth,
# 308 MB) → ~/duo-hack/build/library (about 54 MB). CAF records the encoder delay, so loops keep their exact length.
# loops.json / oneshots.json are copied with each "file" pointing at the .caf. Re-run after changing the library,
# then rebuild the app (project.yml bundles the output folder).
set -euo pipefail
SRC=${SRC:-$HOME/duo-hack/library}
OUT=${OUT:-$HOME/duo-hack/build/library}
BITRATE=${BITRATE:-256000}
TMP="$OUT.tmp"

rm -rf "$TMP"
mkdir -p "$TMP"
cd "$SRC"
find loops oneshots -name '*.wav' -print0 | xargs -0 -P 8 -I{} sh -c '
  mkdir -p "$1/$(dirname "$2")"
  afconvert -f caff -d aac -b "$3" "$2" "$1/${2%.wav}.caf"
' _ "$TMP" {} "$BITRATE"

python3 - "$SRC" "$TMP" <<'EOF'
import json, os, shutil, sys
src, out = sys.argv[1:]
for name, key in (("loops.json", "loops"), ("oneshots.json", "samples")):
    with open(os.path.join(src, name)) as f:
        data = json.load(f)
    for item in data[key]:
        if item["file"].endswith(".wav"):
            item["file"] = item["file"][:-4] + ".caf"
        if not os.path.exists(os.path.join(out, item["file"])):
            sys.exit(f"missing {item['file']}")
    with open(os.path.join(out, name), "w") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
for name in ("grooves.json", "demo_samples.json"):
    shutil.copy2(os.path.join(src, name), os.path.join(out, name))
EOF

rm -rf "$OUT"
mv "$TMP" "$OUT"
echo "$(find "$OUT" -name '*.caf' | wc -l | tr -d ' ') sounds, $(du -sh "$OUT" | cut -f1) → $OUT"
