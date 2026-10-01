#!/bin/bash
# Archive CRATE and upload it to App Store Connect for TestFlight.
#
# One-time setup (needs a paid Apple Developer account):
#   1. developer.apple.com → Identifiers → App ID "com.shuhan.crate".
#   2. appstoreconnect.apple.com → Apps → + New App (iOS, bundle id com.shuhan.crate, SKU "crate").
#   3. Either sign in to Xcode with the developer Apple ID (Xcode → Settings → Accounts), or create an
#      App Store Connect API key (Users and Access → Integrations, role App Manager) and pass ASC_KEY_ID,
#      ASC_ISSUER_ID and ASC_KEY_PATH (keep the .p8 outside the repo).
#
# Upload a build (Shuhan's team is 9R86FG9KG8):
#   TEAM_ID=9R86FG9KG8 tools/testflight.sh
#
# Check that a Release archive builds, without signing or uploading anything:
#   DRY_RUN=1 tools/testflight.sh
#
# XCODE picks the toolchain:
#   release (default) /Applications/Xcode.app, Xcode 27.0. App Store Connect accepts it for TestFlight and review.
#                     The Duo APIs compile out (NO_DUO_SDK), so a Duo gets the iPhone layout, without hinge FX.
#   beta              ~/Downloads/Xcode.app, Xcode 27.1 beta with the Duo SDK. Full Duo build; Apple takes beta-SDK
#                     uploads for TestFlight only once it enables that SDK, and never for App Store review.
set -euo pipefail
cd "$(dirname "$0")/.."

case "${XCODE:-release}" in
  release) export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ;;
  beta)    export DEVELOPER_DIR="$HOME/Downloads/Xcode.app/Contents/Developer" ;;
  *)       echo "XCODE must be release or beta" >&2; exit 1 ;;
esac
[ -f Config/Secrets.xcconfig ] || { echo "Config/Secrets.xcconfig is missing (CRATE_APP_TOKEN); see HANDOFF.md" >&2; exit 1; }

OUT="build/testflight"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"   # must go up with every upload of the same version
ARCHIVE="$OUT/Crate-$BUILD_NUMBER.xcarchive"
mkdir -p "$OUT"
xcodegen generate >/dev/null
echo "Xcode: $(xcodebuild -version | head -1) · build $BUILD_NUMBER"

if [ -n "${DRY_RUN:-}" ]; then
  xcodebuild -project Crate.xcodeproj -scheme Crate -configuration Release -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE" -derivedDataPath build/dd-release CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    CODE_SIGNING_ALLOWED=NO archive -quiet
  APP="$ARCHIVE/Products/Applications/Crate.app"
  echo "Archive OK (unsigned): $ARCHIVE"
  echo "App size: $(du -sh "$APP" | cut -f1) · min iOS $(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$APP/Info.plist")"
  exit 0
fi

: "${TEAM_ID:?set TEAM_ID (developer.apple.com → Membership details)}"
AUTH=(-allowProvisioningUpdates)   # uses the Apple ID signed in to Xcode…
if [ -n "${ASC_KEY_ID:-}" ]; then  # …or an App Store Connect API key
  AUTH+=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi

if [ ! -d "$ARCHIVE" ]; then
  xcodebuild -project Crate.xcodeproj -scheme Crate -configuration Release -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE" -derivedDataPath build/dd-release \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY="Apple Development" \
    "${AUTH[@]}" archive -quiet
  echo "Archived: $ARCHIVE"
fi
[ -n "${ARCHIVE_ONLY:-}" ] && exit 0   # e.g. before the App Store Connect app record exists; rerun with the same BUILD_NUMBER to upload

cat > "$OUT/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
EOF

xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$OUT/ExportOptions.plist" \
  -exportPath "$OUT/export-$BUILD_NUMBER" "${AUTH[@]}"
echo "Uploaded build $BUILD_NUMBER. It shows up in App Store Connect → TestFlight after processing (about 10–30 min)."
