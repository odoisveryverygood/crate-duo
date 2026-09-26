#!/bin/bash
# CRATE demo-flow self-test: drives the real app on the iPhone Duo simulator, then analyzes logs + recorded audio.
# Usage: tools/selftest.sh [--offline] [--no-build]
set -uo pipefail
cd "$(dirname "$0")/.."
U=${UDID:-0F3EDA96-26C2-468E-AAC2-2B28AE79F3B4}
APP=build/dd/Build/Products/Debug-iphonesimulator/Crate.app
OUT=${OUT:-/tmp/crate-selftest}
OFF=0; BUILD=1
for a in "$@"; do [[ $a == --offline ]] && OFF=1; [[ $a == --no-build ]] && BUILD=0; done
[[ $OFF == 1 ]] && OUT=${OUT}-offline
rm -rf "$OUT"; mkdir -p "$OUT"

if [[ $BUILD == 1 ]]; then
  xcodegen generate -q
  xcodebuild -project Crate.xcodeproj -scheme Crate -destination "platform=iOS Simulator,id=$U" -derivedDataPath build/dd -quiet build 2>&1 | grep -E "error:" && { echo "BUILD FAILED"; exit 1; }
fi

now() { python3 -c 'import time;print(time.time())'; }
mark() { echo "{\"event\":\"mark\",\"name\":\"$1\",\"t\":$(now)}" >> "$OUT/marks.jsonl"; echo "· $1"; }
shot() { xcrun simctl io "$U" screenshot "$OUT/$1.png" >/dev/null 2>&1; }
CMD=/tmp/crate-cmd.txt; : > "$CMD"
url() { echo "crate://$1" >> "$CMD"; sleep 0.15; }
enc() { python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$1"; }

xcrun simctl install "$U" "$APP"
hinge 150 >/dev/null 2>&1
xcrun simctl launch --console-pty --terminate-running-process "$U" com.shuhan.crate \
  -crateDebugLog 1 -crateDebugRecord 1 -crateOffline $OFF -crateNoPaywall 1 -crateCmdFile "$CMD" > "$OUT/console.log" 2>&1 &
sleep 3
mark launched; shot 00-launch

mark dig1; url "dig?q=$(enc '4 bar loop, j dilla laid back drums and a killer nujabes piano sample')"
sleep 10; shot 01-dilla-nujabes
url "mode?m=chop"; sleep 1.2; shot 02-chop
url "mode?m=seq"
mark dig2; url "dig?q=$(enc 'fill up the pads with some house drums')"
sleep 7; shot 03-house
mark fold; hinge sweep 150 30 3 >/dev/null 2>&1; shot 04-folded; sleep 0.8
hinge 150 >/dev/null 2>&1; mark snap; sleep 3; shot 05-drop
url "mode?m=keys"; url "bank?b=C"; sleep 0.5
mark keys; for s in 0 3 5 7 10 12; do url "pad?b=C&i=1&semi=$s"; sleep 0.3; done; shot 06-keys
url "mode?m=seq"; mark perform; url "perform?on=1"; sleep 12; shot 07-perform
url "perform?on=0"; mark end; url stop; sleep 1.5

DATA=$(xcrun simctl get_app_container "$U" com.shuhan.crate data 2>/dev/null)
cp "$DATA/Documents/crate-debug.wav" "$OUT/" 2>/dev/null || echo "!! no crate-debug.wav"
~/forkdaw/.venv/bin/python tools/analyze.py "$OUT"
