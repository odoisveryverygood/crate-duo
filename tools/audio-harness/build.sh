#!/bin/sh
# Builds the macOS audio harness (Core + Audio + harness main) into $OUT (default: /tmp/crate-audio-harness).
set -e
cd "$(dirname "$0")/../.."
OUT="${OUT:-/tmp/crate-audio-harness}"
xcrun swiftc -O -sdk "$(xcrun --sdk macosx --show-sdk-path)" -target arm64-apple-macosx27.0 -swift-version 5 \
  Sources/Core/*.swift Sources/Audio/*.swift tools/audio-harness/main.swift -o "$OUT"
echo "built $OUT"
