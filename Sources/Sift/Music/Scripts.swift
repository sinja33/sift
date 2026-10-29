// Scripts sent to the Music app. JavaScript for Automation unless noted.
// Track IDs are Music's persistent IDs, passed in through argv.
enum Scripts {
    /// Returns every song in the library as a JSON array.
    static let loadSongs = #"""
    function run(argv) {
      const music = Application('Music');
      const tracks = music.libraryPlaylists[0].tracks;
      const ids = tracks.persistentID();
      if (ids.length === 0) return '[]';
      const names = tracks.name();
      const artists = tracks.artist();
      const albums = tracks.album();
      const durations = tracks.duration();
      const plays = tracks.playedCount();
      const skips = tracks.skippedCount();
      const played = tracks.playedDate();
      const added = tracks.dateAdded();
      const kinds = tracks.mediaKind();
      const notMusic = ['video', 'movie', 'tv', 'podcast', 'book', 'itunesu', 'memo'];
      const songs = [];
      for (let i = 0; i < ids.length; i++) {
        const kind = String(kinds[i] || '').toLowerCase();
        if (notMusic.some(function (k) { return kind.indexOf(k) !== -1; })) continue;
        songs.push({
          id: ids[i],
          title: names[i] || '',
          artist: artists[i] || '',
          album: albums[i] || '',
          duration: durations[i] || 0,
          playCount: plays[i] || 0,
          skipCount: skips[i] || 0,
          lastPlayed: played[i] ? played[i].toISOString() : null,
          dateAdded: added[i] ? added[i].toISOString() : null
        });
      }
      return JSON.stringify(songs);
    }
    """#

    // The commands below are AppleScript. Music rejects JavaScript `whose` references in
    // commands like play and delete (error -1708), while AppleScript's `every track whose`
    // resolves to concrete track references that Music accepts.

    /// argv: [id, start second as a whole number]
    static let play = #"""
    on run argv
      set pid to item 1 of argv
      set startAt to (item 2 of argv) as integer
      tell application "Music"
        set found to (every track of library playlist 1 whose persistent ID is pid)
        if (count of found) is 0 then return "missing"
        play (item 1 of found)
        delay 0.4
        set player position to startAt
      end tell
      return "ok"
    end run
    """#

    static let pause = #"""
    tell application "Music"
      if player state is playing then pause
    end tell
    """#

    /// argv: ids. Returns how many tracks were deleted.
    static let delete = #"""
    on run argv
      set deleted to 0
      tell application "Music"
        repeat with pid in argv
          set found to (every track of library playlist 1 whose persistent ID is (pid as text))
          if (count of found) > 0 then
            delete (item 1 of found)
            set deleted to deleted + 1
          end if
        end repeat
      end tell
      return deleted as text
    end run
    """#

    /// argv: [playlist name, ids...]. Creates the playlist if needed.
    static let addToPlaylist = #"""
    on run argv
      set listName to item 1 of argv
      tell application "Music"
        if not (exists user playlist listName) then make new user playlist with properties {name:listName}
        set pl to user playlist listName
        repeat with i from 2 to (count of argv)
          set pid to item i of argv
          set found to (every track of library playlist 1 whose persistent ID is pid)
          if (count of found) > 0 then
            if (count of (every track of pl whose persistent ID is pid)) is 0 then
              duplicate (item 1 of found) to pl
            end if
          end if
        end repeat
      end tell
      return "ok"
    end run
    """#

    /// argv: [playlist name, ids...]. Removes the songs from the playlist only.
    static let removeFromPlaylist = #"""
    on run argv
      set listName to item 1 of argv
      tell application "Music"
        if not (exists user playlist listName) then return "ok"
        set pl to user playlist listName
        repeat with i from 2 to (count of argv)
          set pid to item i of argv
          set found to (every track of pl whose persistent ID is pid)
          if (count of found) > 0 then delete (item 1 of found)
        end repeat
      end tell
      return "ok"
    end run
    """#

    /// AppleScript. argv: [id, output path]. Writes the first artwork to the path.
    static let artwork = #"""
    on run argv
      set pid to item 1 of argv
      set outPath to item 2 of argv
      tell application "Music"
        set t to first track of library playlist 1 whose persistent ID is pid
        if (count of artworks of t) is 0 then return "none"
        set d to raw data of artwork 1 of t
      end tell
      set f to open for access (POSIX file outPath) with write permission
      set eof of f to 0
      write d to f
      close access f
      return "ok"
    end run
    """#
}
