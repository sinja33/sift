# Sift

**Swipe through your Apple Music library and clear out the songs you never play.**

You know those thousands of songs you added years ago and never listen to? Sift finds them, plays a short clip of each one so you remember what it is, and lets you decide in a second:

| Swipe | What happens |
| --- | --- |
| ⬅️ **Left** | Delete it |
| ➡️ **Right** | Keep it |
| ⬆️ **Up** | Not sure? Give it a **Second Chance** |

Second Chance songs go into a playlist called "Second Chance" that shows up on your iPhone too. Three weeks later Sift checks whether you actually played them and helps you decide for good.

**Nothing is deleted until you say so.** Every song you swipe away waits on a review screen, where you can look over the list and untick anything before confirming.

It's free, and it runs on your Mac. Your library never gets uploaded anywhere.

---

## Get Sift on your Mac

**What you need:** a Mac with **macOS 14 (Sonoma) or newer** and your songs in the **Music** app. Not sure which macOS you have? Click the Apple menu  in the top-left corner and choose **About This Mac**.

It takes about two minutes:

### 1. Download it

Go to the **[download page](../../releases/latest)** and click **Sift-1.0.0.dmg** (the number may be higher). It lands in your **Downloads** folder.

### 2. Install it

Double-click the file you downloaded. A small window opens with the Sift icon and an Applications folder. **Drag Sift onto the Applications folder.** That's it. You can close the window.

### 3. Open it the first time

Open your **Applications** folder and double-click **Sift**.

The first time, your Mac shows a warning that it **"could not verify Sift is free of malware"**. Don't worry: you see this with any free app made by someone who doesn't pay Apple's yearly developer fee. To open it anyway:

1. Click **Done** (not "Move to Trash").
2. Open the Apple menu  → **System Settings** → **Privacy & Security**.
3. Scroll down until you see **"Sift was blocked to protect your Mac"** and click **Open Anyway**.
4. Enter your Mac password if it asks, then click **Open Anyway** once more.

You only ever do this once.

> On **macOS 14 (Sonoma)** it's quicker: in Applications, **right-click** Sift, choose **Open**, then click **Open**.

### 4. Connect it to Music

Click **Connect to Music**. Your Mac asks whether Sift may control Music. **Click OK.** Sift reads your library, which takes a few seconds for big ones, and you're ready to swipe.

> **Clicked "Don't Allow" by mistake?** Open System Settings → Privacy & Security → **Automation**, find Sift and switch **Music** on.

**Tip:** if you want deleted songs to disappear from your iPhone as well, make sure **Sync Library** is on in Music (Music → Settings → General).

---

## How a session goes

1. On the Home screen, press **Start session**. Sift picks 20 songs you rarely play.
2. Each song plays a short clip. Swipe it, drag it, click the buttons under it or use the arrow keys.
3. When you're done (or whenever you like), press **Review and delete**, look over the list and confirm.

A few nice touches along the way:

- **Artist spotlight.** Home suggests an artist you hardly ever play, so you can go through all their songs at once.
- **Artist stop.** Delete three songs by the same artist and Sift offers to go through the rest of theirs.
- **Pick up later.** Leave in the middle of a session and Home lets you continue where you stopped.
- **Undo.** Press ⌘Z if you swiped the wrong way.

### Keyboard shortcuts

| Key | Does |
| --- | --- |
| ← | Delete (or Keep if you swapped directions in Settings) |
| → | Keep (or Delete) |
| ↑ | Second Chance |
| Space | Play the clip again |
| S | Skip a song |
| ⌘Z | Undo |
| Return / Esc | Accept or skip an artist stop |

### Which songs come up

Songs you've never played, haven't played in a long time, or keep skipping come first. Sift leaves out songs you added in the last 30 days, songs you kept in the last 6 months, and songs already waiting in Second Chance or on the review screen.

---

## Questions

**Is it safe? Can I lose songs by accident?**
Swiping never deletes anything by itself. Songs only leave your library after you press **Delete** on the review screen and confirm. There you can also tick a box to save a list of the deleted songs (a spreadsheet file in Documents → Sift Backups), so you can find them again later.

**Can I undo a delete?**
Not after confirming. Apple Music has no undo for deleting songs, which is why Sift asks first. If the songs came from Apple Music, you can always search for them and add them again.

**What does Sift send over the internet?**
Only small lookups, never your library: the artist and title to find a song's preview clip and cover on Apple's iTunes search, an artist's name to find their photo on Deezer, and once per launch a check on GitHub for a newer version (you can turn that off in Settings). Offline, Sift still works and just shows placeholders.

**Does playing clips count as a play?**
No. Clips are Apple's short previews, so your play counts stay as they are. Songs without a preview play through Music instead.

**How do I update?**
When there's a new version, Home shows a banner. Download it the same way, drag it into Applications and choose **Replace**. Your progress stays.

**How do I remove Sift?**
Drag Sift from Applications to the Trash. To also remove what it remembers, delete the **Sift** folder in `~/Library/Application Support`.

**Something isn't working.**
[Open an issue](../../issues) and describe what happened. A screenshot helps.

---

## For developers

Apple doesn't let iPhone or web apps delete songs from your library, but the Music app on the Mac can be scripted. Sift talks to it through `osascript` (see `Sources/Sift/Music/Scripts.swift`) to read play counts, play clips, manage the Second Chance playlist and delete songs. Sift's own memory (kept songs, Second Chance dates) lives in `~/Library/Application Support/Sift/state.json`. Previews, covers and artist photos are cached in `~/Library/Caches/Sift`.

### Build and test

You need Apple's free developer tools: **Xcode** from the App Store, or just the Command Line Tools (`xcode-select --install`).

```bash
bash scripts/build-app.sh     # builds build/Sift.app
open build/Sift.app
bash scripts/test.sh          # runs the tests
```

To work in Xcode, open `Package.swift` and press Run.

### Publish a release

Push a version tag. GitHub runs the tests, builds the app for Apple Silicon and Intel Macs, and attaches the `.dmg` and `.zip` to a new release:

```bash
git tag v1.0.1
git push origin v1.0.1
```

To build the download locally instead, run `VERSION=1.0.1 bash scripts/make-dmg.sh`. The files land in `dist/`.

### Project layout

```
Sources/Sift/
  SiftApp.swift          App entry point
  Music/                 Talking to the Music app, previews, covers, artist photos
  Model/                 App state, scoring, saved data, update check
  Views/                 Screens and components (colours and fonts in Theme.swift)
Tests/SiftTests/         Tests, plus an optional screen render for checking layouts
Support/                 Info.plist and app icon
scripts/                 Build, test, disk image and icon scripts
.github/workflows/       Builds a release when you push a version tag
```
