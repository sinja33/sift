#!/bin/bash
# Redraws Support/dmg-background.tiff, the picture behind the install window, from scripts/dmg/background.swift.
# The .tiff holds a normal and a Retina version, so it stays sharp on every screen.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP="$(mktemp -d)"
swift scripts/dmg/background.swift "$TMP/background.png" 1
swift scripts/dmg/background.swift "$TMP/background@2x.png" 2
tiffutil -cathidpicheck "$TMP/background.png" "$TMP/background@2x.png" -out Support/dmg-background.tiff
rm -rf "$TMP"
echo "Wrote Support/dmg-background.tiff"
