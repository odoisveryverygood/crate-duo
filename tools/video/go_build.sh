#!/bin/zsh
# go_build.sh <udid> -- build origin/main HEAD (what the lead pushed) in a clean
# export with its own derived data, and install it on the video simulator.
# Never touches crate-int or the crate-build checkout's files (only `git fetch`).
set -e
UDID=$1
REPO=/Users/shuhanzhang/crate-build
WORK=${VIDEO_BUILD_DIR:-/private/tmp/claude-503/-Users-shuhanzhang/e4350d56-7646-49d3-90c7-6512aef4989d/scratchpad/v3build}
git -C $REPO fetch origin main
SHA=$(git -C $REPO rev-parse origin/main)
echo "origin/main = $SHA"
rm -rf $WORK/src && mkdir -p $WORK/src
git -C $REPO archive $SHA | tar -x -C $WORK/src
cp $REPO/Config/Secrets.xcconfig $WORK/src/Config/Secrets.xcconfig
cd $WORK/src && xcodegen generate > /dev/null
xcodebuild -project Crate.xcodeproj -scheme Crate -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath $WORK/dd -quiet build
xcrun simctl install $UDID $WORK/dd/Build/Products/Debug-iphonesimulator/Crate.app
echo "installed $SHA on $UDID"
echo $SHA > $WORK/built_sha.txt
