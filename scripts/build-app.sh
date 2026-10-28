#!/bin/bash
# Builds Sift.app into ./build. Needs Xcode or the Xcode Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Sift"

APP="build/Sift.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Sift"
cp Support/Info.plist "$APP/Contents/Info.plist"
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature so macOS can remember the Music permission.
codesign --force --sign - "$APP"

echo "Built $APP"
echo "Open it with: open $APP"
