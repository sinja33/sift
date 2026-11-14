#!/bin/bash
# Writes dist/appcast.xml, the list Sift's updater reads to find a new version (see Sources/Sift/Model/AppUpdater.swift).
# It points at the release's .zip and carries its signature, made with the private key in SPARKLE_PRIVATE_KEY
# (a GitHub secret; the same key sits in the login keychain of the Mac that created it, under "sift").
#   VERSION=1.2 SPARKLE_PRIVATE_KEY=... scripts/make-appcast.sh
set -euo pipefail
cd "$(dirname "$0")/.."

: "${VERSION:?set VERSION}"
: "${SPARKLE_PRIVATE_KEY:?set SPARKLE_PRIVATE_KEY}"
ZIP="dist/Sift-$VERSION.zip"
URL="https://github.com/sinja33/sift/releases/download/v$VERSION/Sift-$VERSION.zip"
MIN_OS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' Support/Info.plist)"

KEY="$(mktemp)"
trap 'rm -f "$KEY"' EXIT
printf '%s' "$SPARKLE_PRIVATE_KEY" > "$KEY"
# Prints: sparkle:edSignature="..." length="..."
SIGNATURE="$(.build/artifacts/sparkle/Sparkle/bin/sign_update --ed-key-file "$KEY" "$ZIP")"

cat > dist/appcast.xml <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Sift</title>
    <item>
      <title>Sift $VERSION</title>
      <pubDate>$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')</pubDate>
      <sparkle:version>$VERSION</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$MIN_OS</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>https://github.com/sinja33/sift/releases/tag/v$VERSION</sparkle:releaseNotesLink>
      <enclosure url="$URL" type="application/octet-stream" $SIGNATURE />
    </item>
  </channel>
</rss>
XML
echo "Wrote dist/appcast.xml"
