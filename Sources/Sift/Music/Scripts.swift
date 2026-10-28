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

    /// argv: [id, startSeconds]
    static let play = #"""
    function run(argv) {
      const music = Application('Music');
      const found = music.libraryPlaylists[0].tracks.whose({ persistentID: argv[0] });
      if (found.length === 0) return 'missing';
      music.play(found[0]);
      delay(0.4);
      music.playerPosition = parseFloat(argv[1]);
      return 'ok';
    }
    """#

    static let pause = #"""
    function run(argv) {
      const music = Application('Music');
      if (music.playerState() === 'playing') music.pause();
      return 'ok';
    }
    """#

    /// argv: [JSON array of ids]. Returns how many tracks were deleted.
    static let delete = #"""
    function run(argv) {
      const music = Application('Music');
      const tracks = music.libraryPlaylists[0].tracks;
      const ids = JSON.parse(argv[0]);
      let deleted = 0;
      for (const id of ids) {
        const found = tracks.whose({ persistentID: id });
        if (found.length > 0) {
          found[0].delete();
          deleted++;
        }
      }
      return String(deleted);
    }
    """#

    /// argv: [playlist name, JSON array of ids]. Creates the playlist if needed.
    static let addToPlaylist = #"""
    function run(argv) {
      const music = Application('Music');
      const name = argv[0];
      const ids = JSON.parse(argv[1]);
      if (music.userPlaylists.whose({ name: name }).length === 0) {
        music.userPlaylists.push(music.UserPlaylist({ name: name }));
      }
      const playlist = music.userPlaylists.whose({ name: name })[0];
      const tracks = music.libraryPlaylists[0].tracks;
      for (const id of ids) {
        const found = tracks.whose({ persistentID: id });
        if (found.length > 0 && playlist.tracks.whose({ persistentID: id }).length === 0) {
          music.duplicate(found[0], { to: playlist });
        }
      }
      return 'ok';
    }
    """#

    /// argv: [playlist name, JSON array of ids]. Removes the songs from the playlist only.
    static let removeFromPlaylist = #"""
    function run(argv) {
      const music = Application('Music');
      const lists = music.userPlaylists.whose({ name: argv[0] });
      if (lists.length === 0) return 'ok';
      const tracks = lists[0].tracks;
      for (const id of JSON.parse(argv[1])) {
        const found = tracks.whose({ persistentID: id });
        if (found.length > 0) found[0].delete();
      }
      return 'ok';
    }
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
