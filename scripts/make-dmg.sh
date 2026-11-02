#!/bin/bash
# Builds a universal Sift.app and packs it into dist/Sift-<version>.dmg and dist/Sift-<version>.zip.
#   VERSION=1.2 scripts/make-dmg.sh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Support/Info.plist)}"
export VERSION
UNIVERSAL=1 scripts/build-app.sh

mkdir -p dist
STAGE="$(mktemp -d)"
cp -R build/Sift.app "$STAGE/Sift.app"
ln -s /Applications "$STAGE/Applications"

rm -f "dist/Sift-$VERSION.dmg" "dist/Sift-$VERSION.zip"
hdiutil create -volname "Sift" -srcfolder "$STAGE" -ov -format UDZO "dist/Sift-$VERSION.dmg"
ditto -c -k --keepParent build/Sift.app "dist/Sift-$VERSION.zip"
rm -rf "$STAGE"

echo "Wrote dist/Sift-$VERSION.dmg and dist/Sift-$VERSION.zip"
