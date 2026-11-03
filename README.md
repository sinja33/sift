# Sift

A Mac app for cleaning up your Apple Music library. Sift finds the songs you never play, plays a short clip of each one, and lets you swipe:

- **Left** to delete it
- **Right** to keep it
- **Up** to give it a Second Chance

Second Chance songs go into a "Second Chance" playlist that syncs to your iPhone. Three weeks later, Sift shows you a round with how often you played each one since, and suggests whether to keep or delete it.

Nothing is deleted until you confirm on the review screen. Sift also saves a backup list (CSV) of deleted songs to `Documents/Sift Backups`.

## Download

1. Go to the [latest release](../../releases/latest) and download **Sift-x.y.z.dmg**.
2. Open the file and drag **Sift** onto the **Applications** folder.
3. Open Sift from Applications. The first time, macOS says it can't check the app for malware, because Sift isn't signed with a paid Apple developer certificate. This is normal for free apps like this one. To open it anyway:
   - **macOS 15 and newer:** click **Done**, then open **System Settings → Privacy & Security**, scroll down to the message about Sift and click **Open Anyway**.
   - **macOS 14:** right-click (or Control-click) Sift in Applications, choose **Open**, then click **Open**.
   You only do this once.
4. Click **Connect to Music**. macOS asks whether Sift may control Music. Click **OK**. If you click Don't Allow by mistake, turn it back on in System Settings → Privacy & Security → Automation → Sift → Music.

You need a Mac with macOS 14 (Sonoma) or newer and the Music app with your library in it. Turn on Sync Library in Music if you want deletes to reach your iPhone.

## Build it yourself

You only need this if you want to change the code. It needs Apple's free developer tools: **Xcode** from the App Store, or just the Command Line Tools (`xcode-select --install` in Terminal).

```bash
cd path/to/sift
bash scripts/build-app.sh
open build/Sift.app
```

To work on the code in Xcode instead, open `Package.swift` in Xcode and press Run.

## Publishing a release

Tag a version and push the tag. GitHub builds the app for Apple Silicon and Intel Macs and attaches the `.dmg` and `.zip` to a new release:

```bash
git tag v1.0.0
git push origin v1.0.0
```

To build the download on your own Mac instead, run `VERSION=1.0.0 bash scripts/make-dmg.sh`. The files land in `dist/`.

## Shortcuts on the swipe screen

| Key | Action |
| --- | --- |
| ← | Delete (or Keep if you switched directions) |
| → | Keep (or Delete) |
| ↑ | Second Chance |
| Space | Replay the clip |
| S | Skip a song you can't play |
| ⌘Z | Undo |
| Return / Esc | Accept or skip an artist stop |

You can also drag the card with the mouse or trackpad, or click the buttons under it.

## How songs are picked

Each session shows 20 songs by default (you can change it in Settings) most likely to be clutter. Never-played songs, songs you haven't played in a long time, and often-skipped songs come first. Sift leaves out:

- songs added in the last 30 days
- songs you kept in the last 6 months
- songs already in Second Chance or waiting to be deleted

## Artist stop and spotlight

After you delete three songs by one artist in a session, Sift offers to go through the rest of their songs right away, then carries on with your session.

The Home screen offers an artist you rarely play, and you can go through all of their songs in one session. Music has no artist pictures, so Sift looks up the photo on Deezer's public search. Only the artist's name is sent, nothing else about your library. Photos are cached in `~/Library/Caches/Sift`, and a letter tile is shown when none is found.

## Covers, updates, sound and privacy

Sift never uploads your library. It goes online in three small ways, and only to look things up:

- **Artist photos** from Deezer, sending only the artist's name (see above).
- **Missing album covers** from Apple's public iTunes Search, sending only the artist and song title. Covers are cached in `~/Library/Caches/Sift`.
- **Update check**: once per launch Sift asks GitHub for the newest release number and shows a banner when there is one. Turn it off in Settings.

If you are offline, Sift still works. Covers and photos just show a placeholder.

Sounds and trackpad taps on each swipe can be turned off in Settings.

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
scripts/make-dmg.sh      Builds the downloadable .dmg and .zip into dist/
scripts/make-icon.sh     Redraws the app icon from Views/LogoDrawing.swift
.github/workflows/       Builds a release when you push a version tag
```
