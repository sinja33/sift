#!/bin/bash
# Builds a universal Sift.app and packs it into dist/Sift-<version>.dmg and dist/Sift-<version>.zip.
# The disk image opens as a styled install window (see scripts/dmg/dmg-settings.py).
#   VERSION=1.2 scripts/make-dmg.sh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Support/Info.plist)}"
export VERSION
UNIVERSAL=1 scripts/build-app.sh

# dmgbuild lays out the window without driving Finder, so it also works on build servers.
VENV=".build/dmgbuild-1.6.5"
if [ ! -x "$VENV/bin/dmgbuild" ]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --quiet --disable-pip-version-check "dmgbuild==1.6.5"
fi

mkdir -p dist
rm -f "dist/Sift-$VERSION.dmg" "dist/Sift-$VERSION.zip"
# A small helper makes the background's file link with macOS's own API (see scripts/dmg/build-dmg.py).
swiftc -O -o .build/dmg-bookmark scripts/dmg/bookmark.swift
"$VENV/bin/python" scripts/dmg/build-dmg.py .build/dmg-bookmark scripts/dmg/dmg-settings.py build/Sift.app "dist/Sift-$VERSION.dmg"
ditto -c -k --keepParent build/Sift.app "dist/Sift-$VERSION.zip"

echo "Wrote dist/Sift-$VERSION.dmg and dist/Sift-$VERSION.zip"
