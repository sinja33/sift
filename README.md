# Sift

A Mac app for cleaning up your Apple Music library. Sift finds the songs you never play, plays a short clip of each one, and lets you swipe:

- **Left** to delete it
- **Right** to keep it
- **Up** to give it a Second Chance

Second Chance songs go into a "Second Chance" playlist that syncs to your iPhone. Three weeks later, Sift shows you a round with how often you played each one since, and suggests whether to keep or delete it.

Nothing is deleted until you confirm on the review screen. Sift also saves a backup list (CSV) of deleted songs to `Documents/Sift Backups`.

## What you need

- A Mac with macOS 14 (Sonoma) or newer
- The Music app with your library in it (iCloud Music Library / Sync Library on, if you want deletes to reach your iPhone)
- Apple's free developer tools: either **Xcode** from the App Store, or just the Command Line Tools (`xcode-select --install` in Terminal)

You don't need a paid Apple Developer account.

## Build and run

In Terminal:

```bash
cd path/to/sift
bash scripts/build-app.sh
open build/Sift.app
```

The first time, macOS asks whether Sift may control Music. Click **OK**. If you click Don't Allow by mistake, turn it back on in System Settings → Privacy & Security → Automation → Sift → Music.

You can drag `build/Sift.app` into your Applications folder to keep it.

To work on the code in Xcode instead, open `Package.swift` in Xcode and press Run.

## Shortcuts on the swipe screen

| Key | Action |
| --- | --- |
| ← | Delete (or Keep if you switched directions) |
| → | Keep (or Delete) |
| ↑ | Second Chance |
| Space | Replay the clip |
| ⌘Z | Undo |

You can also drag the card with the mouse or trackpad, or click the buttons under it.

## How songs are picked

Each session shows the 20 songs most likely to be clutter. Never-played songs, songs you haven't played in a long time, and often-skipped songs come first. Sift leaves out:

- songs added in the last 30 days
- songs you kept in the last 6 months
- songs already in Second Chance or waiting to be deleted

## How it works

Apple doesn't let iPhone or web apps delete songs from your library. The Music app on the Mac can be scripted, though, so Sift talks to it through `osascript` (see `Sources/Sift/Music/Scripts.swift`). That's how it reads play counts, plays clips, manages the Second Chance playlist, and deletes songs.

Sift keeps its own memory (kept songs, Second Chance dates) in `~/Library/Application Support/Sift/state.json`.

## Project layout

```
Sources/Sift/
  SiftApp.swift          App entry point
  Music/                 Talking to the Music app
  Model/                 App state, scoring, saved data
  Views/                 Screens and components (colours in Theme.swift)
Support/                 Info.plist and app icon
scripts/build-app.sh     Builds build/Sift.app
```
