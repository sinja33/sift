#!/bin/bash
# Regenerates Support/AppIcon.icns from the logo drawing in Sources/Sift/Views/LogoDrawing.swift.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP="$(mktemp -d)"
swiftc -o "$TMP/make-icon" scripts/icon/main.swift Sources/Sift/Views/LogoDrawing.swift
"$TMP/make-icon" "$TMP/AppIcon.iconset"
iconutil -c icns "$TMP/AppIcon.iconset" -o Support/AppIcon.icns
rm -rf "$TMP"
echo "Wrote Support/AppIcon.icns"
