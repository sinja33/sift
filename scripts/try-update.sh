#!/bin/bash
# Tries the in-app update on this Mac without publishing anything. It builds a test copy of Sift "1.0.4" and a
# signed "1.0.5", serves the update from this Mac, and opens the test copy, which then shows the update banner.
# Click Update in the banner. The test copy lives in a temporary folder; your real Sift is not touched.
# Signing uses the key in your login keychain (account "sift"). Press Ctrl-C to stop when done.
set -euo pipefail
cd "$(dirname "$0")/.."

OLD=1.0.4 NEW=1.0.5 PORT=8765
DIR="$(mktemp -d)/sift-update-test"
mkdir -p "$DIR/app" "$DIR/feed"

VERSION=$NEW scripts/build-app.sh >/dev/null
ditto -c -k --keepParent build/Sift.app "$DIR/feed/Sift-$NEW.zip"
VERSION=$OLD scripts/build-app.sh >/dev/null
ditto build/Sift.app "$DIR/app/Sift.app"
/usr/libexec/PlistBuddy -c "Set :SUFeedURL http://localhost:$PORT/appcast.xml" "$DIR/app/Sift.app/Contents/Info.plist"
codesign --force --sign - "$DIR/app/Sift.app" 2>/dev/null

SIGNATURE="$(.build/artifacts/sparkle/Sparkle/bin/sign_update --account sift "$DIR/feed/Sift-$NEW.zip")"
cat > "$DIR/feed/appcast.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel><title>Sift</title>
    <item><title>Sift $NEW</title><pubDate>$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')</pubDate>
      <sparkle:version>$NEW</sparkle:version><sparkle:shortVersionString>$NEW</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure url="http://localhost:$PORT/Sift-$NEW.zip" type="application/octet-stream" $SIGNATURE />
    </item></channel></rss>
XML
# What the banner reads, in the shape of GitHub's answer.
printf '{"tag_name":"v%s","html_url":"https://github.com/sinja33/sift/releases"}' "$NEW" > "$DIR/feed/latest.json"

(cd "$DIR/feed" && exec python3 -m http.server "$PORT" --bind 127.0.0.1 >/dev/null 2>&1) &
SERVER=$!
trap 'kill $SERVER 2>/dev/null' EXIT
sleep 1

osascript -e 'quit app "Sift"' 2>/dev/null || true
sleep 1
open -n --env SIFT_RELEASES_URL="http://localhost:$PORT/latest.json" "$DIR/app/Sift.app"
echo "Opened the test copy (Sift $OLD) from $DIR/app."
echo "Click Update in the banner on Home. After the restart, Sift → About Sift should say $NEW."
echo "Press Ctrl-C here when done."
wait $SERVER
