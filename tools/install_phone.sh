#!/bin/bash
# Build CRATE (Release, release Xcode) and install it on a paired iPhone / iPad over USB or Wi-Fi.
#   tools/install_phone.sh                 # the first paired physical iPhone / iPad
#   DEVICE=<udid> tools/install_phone.sh   # a specific one (xcrun devicectl list devices)
# Signs with the Xcode account (automatic signing), so the Mac must be unlocked. Wi-Fi installs sometimes drop
# ("Connection interrupted"): it retries twice.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
TEAM_ID=${TEAM_ID:-9R86FG9KG8}
if [ -z "${DEVICE:-}" ]; then
  DEVICE=$(xcrun devicectl list devices 2>/dev/null | grep 'physical' | grep -E '(^|[[:space:]])(available|connected)([[:space:]]|$)' \
    | grep -oE '[0-9A-F]{8}-[0-9A-F]{16}|[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' | head -1 || true)
fi
[ -n "$DEVICE" ] || { echo "No paired device found (xcrun devicectl list devices)"; exit 1; }
echo "Device: $DEVICE"
xcodegen generate -q
xcodebuild -project Crate.xcodeproj -scheme Crate -configuration Release -destination "id=$DEVICE" \
  -derivedDataPath build/dev -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY="Apple Development" build -quiet
APP=build/dev/Build/Products/Release-iphoneos/Crate.app
for i in 1 2 3; do
  if xcrun devicectl device install app --device "$DEVICE" "$APP" 2>&1 | grep -q 'App installed'; then
    echo "Installed on $DEVICE"
    exit 0
  fi
  echo "Install attempt $i failed; retrying"
  sleep 5
done
echo "Install failed. Unlock the device, keep it on the same Wi-Fi (or plug it in) and run again."
exit 1
