#!/bin/bash
# Builds Sift.app into ./build. Needs Xcode or the Xcode Command Line Tools.
#   UNIVERSAL=1  build for Apple Silicon and Intel (used for releases)
#   VERSION=1.2  version shown in Finder (defaults to what is in Info.plist)
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Sift.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

if [ "${UNIVERSAL:-0}" = "1" ]; then
  for arch in arm64 x86_64; do
    swift build -c release --arch "$arch"
  done
  lipo -create \
    "$(swift build -c release --arch arm64 --show-bin-path)/Sift" \
    "$(swift build -c release --arch x86_64 --show-bin-path)/Sift" \
    -output "$APP/Contents/MacOS/Sift"
else
  swift build -c release
  cp "$(swift build -c release --show-bin-path)/Sift" "$APP/Contents/MacOS/Sift"
fi

cp Support/Info.plist "$APP/Contents/Info.plist"
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

if [ -n "${VERSION:-}" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER:-$VERSION}" "$APP/Contents/Info.plist"
fi

# Ad-hoc signature so macOS can remember the Music permission.
codesign --force --sign - "$APP"

echo "Built $APP"
echo "Open it with: open $APP"
