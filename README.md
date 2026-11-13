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

Double-click the file you downloaded. A window opens showing Sift, an arrow and your Applications folder. **Drag Sift onto the Applications folder.** That's it, you can close the window.

> Don't open Sift straight from that window. Drag it into Applications first, otherwise your Mac may not let you approve it in the next step.

### 3. Open it the first time

Open your **Applications** folder and double-click **Sift**.

The first time, your Mac shows a warning: **"Apple could not verify Sift is free of malware"**. Don't worry. You see this with any free app made by someone who doesn't pay Apple's yearly developer fee. To open it anyway:

1. Click **Done**, the grey button. Don't click the blue **Move to Trash**.
2. **Nothing else happens yet, and that's normal.** "Done" only closes the warning. The next step is in System Settings.
3. Open the Apple menu  → **System Settings** → **Privacy & Security**.
4. Scroll all the way down to the **Security** section. You'll see **"Sift" was blocked to protect your Mac**. Click **Open Anyway** next to it.
5. Enter your Mac password (or use Touch ID), then click **Open Anyway** once more. Sift opens.

You only ever do this once. After that Sift opens like any other app.

> **Don't see "Open Anyway"?** Your Mac only shows it for a little while after a blocked attempt. Double-click Sift in Applications again, click **Done**, and go back to Privacy & Security.

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

---

## Coming in Sift 2.0

So far Sift helps you clear out what you don't listen to. Version 2.0 is about finding what you will:

- **Recommended for you.** Sift suggests new songs that fit your taste, based on what you actually play. Each one plays a clip, and you swipe: **right** to add it to your library, **left** to pass.

Want something else in Sift? Suggest it, see the next section.

## Ideas and bugs

Sift is made by one person, and your feedback shapes what comes next.

- **Found a bug?** [Report it here](../../issues/new). Say what you did, what you expected and what happened instead. A screenshot helps a lot.
- **Have an idea or a wish?** [Suggest it here](../../issues/new) too. Small things are welcome, like a setting you're missing or something that felt confusing.
- **Already reported?** Have a look at the [open issues](../../issues) and add a 👍 or a comment to the ones you care about.

You'll need a free GitHub account to post.
