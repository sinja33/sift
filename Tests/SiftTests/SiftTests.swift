import Foundation
import Testing
@testable import Sift

private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let day: TimeInterval = 86_400

private func song(
    _ id: String, artist: String = "Artist", plays: Int = 0, skips: Int = 0,
    addedDaysAgo: Double? = 400, playedDaysAgo: Double? = nil, duration: Double = 200, bytes: Int = 0
) -> Song {
    Song(id: id, title: "Song \(id)", artist: artist, album: "Album", duration: duration, bytes: bytes,
         playCount: plays, skipCount: skips,
         lastPlayed: playedDaysAgo.map { now.addingTimeInterval(-$0 * day) },
         dateAdded: addedDaysAgo.map { now.addingTimeInterval(-$0 * day) })
}

@Suite struct ScoringTests {
    @Test func neverPlayedOldSongScoresAboveFavourite() {
        let clutter = song("a", plays: 0, addedDaysAgo: 900)
        let favourite = song("b", plays: 300, addedDaysAgo: 900, playedDaysAgo: 1)
        #expect(Scoring.clutterScore(clutter, now: now) > Scoring.clutterScore(favourite, now: now))
    }

    @Test func skipsRaiseScore() {
        #expect(Scoring.clutterScore(song("a", skips: 5), now: now) > Scoring.clutterScore(song("b"), now: now))
    }

    @Test func newSongsPendingKeptAndSecondChanceAreNotEligible() {
        var state = SavedState()
        state.pendingDelete = ["pending"]
        state.kept["keptRecently"] = now.addingTimeInterval(-10 * day)
        state.kept["keptLongAgo"] = now.addingTimeInterval(-200 * day)
        state.secondChance["chance"] = ChanceEntry(added: now, playsWhenAdded: 0, skipsWhenAdded: 0, round: 1)

        #expect(!Scoring.isEligible(song("new", addedDaysAgo: 5), state: state, now: now))
        #expect(!Scoring.isEligible(song("pending"), state: state, now: now))
        #expect(!Scoring.isEligible(song("keptRecently"), state: state, now: now))
        #expect(!Scoring.isEligible(song("chance"), state: state, now: now))
        #expect(Scoring.isEligible(song("keptLongAgo"), state: state, now: now))
        #expect(Scoring.isEligible(song("unknownAddDate", addedDaysAgo: nil), state: state, now: now))
    }

    @Test func queueFiltersSortsAndLimits() {
        let songs = [
            song("played", plays: 50, playedDaysAgo: 2),
            song("never"),
            song("skipped", plays: 3, skips: 4, playedDaysAgo: 100),
            song("new", addedDaysAgo: 1),
        ]
        let smart = Scoring.queue(from: songs, state: SavedState(), filter: .smart, limit: 10, now: now)
        #expect(!smart.map(\.id).contains("new"))
        #expect(smart.first?.id == "never")
        #expect(smart.last?.id == "played")

        let never = Scoring.queue(from: songs, state: SavedState(), filter: .neverPlayed, limit: 10, now: now)
        #expect(never.map(\.id) == ["never"])

        let skipped = Scoring.queue(from: songs, state: SavedState(), filter: .oftenSkipped, limit: 10, now: now)
        #expect(skipped.map(\.id) == ["skipped"])

        #expect(Scoring.queue(from: songs, state: SavedState(), filter: .smart, limit: 1, now: now).count == 1)
        #expect(Scoring.queue(from: [], state: SavedState(), filter: .smart, limit: 20, now: now).isEmpty)
    }

    @Test func spotlightNeedsFourSongsAndSkipsUnknownArtist() {
        var songs = (0..<4).map { song("q\($0)", artist: "Quiet", plays: 0) }
        songs += (0..<4).map { song("l\($0)", artist: "Loud", plays: 40) }
        songs += (0..<3).map { song("f\($0)", artist: "Few") }
        songs += (0..<5).map { song("u\($0)", artist: "Unknown Artist") }
        let names = Scoring.spotlightCandidates(from: songs, state: SavedState(), now: now)
        #expect(names == ["Quiet", "Loud"])
    }

    @Test func artistKeyIgnoresCaseAndSpaces() {
        #expect(Scoring.artistKey("  The Band ") == Scoring.artistKey("the band"))
    }

    @Test func clipStartStaysInsideSong() {
        #expect(song("short", duration: 30).clipStart == 0)
        let long = song("long", duration: 300)
        #expect(long.clipStart > 0 && long.clipStart <= 280)
        let mid = song("mid", duration: 45)
        #expect(mid.clipStart + 15 <= 45)
    }
}

@Suite struct FormatTests {
    @Test func duration() {
        #expect(Format.duration(0) == "0:00")
        #expect(Format.duration(65) == "1:05")
        #expect(Format.duration(3599.6) == "60:00")
    }

    @Test func age() {
        #expect(Format.age(nil, now: now) == "never")
        #expect(Format.age(now, now: now) == "today")
        #expect(Format.age(now.addingTimeInterval(-10 * day), now: now) == "10 d")
        #expect(Format.age(now.addingTimeInterval(-90 * day), now: now) == "3 mo")
        #expect(Format.age(now.addingTimeInterval(-800 * day), now: now) == "2 yr")
    }

    @Test func totalTime() {
        #expect(Format.totalTime([song("a", duration: 600)]) == "10 min of music")
        #expect(Format.totalTime([song("a", duration: 3600), song("b", duration: 300)]) == "1 h 5 min of music")
    }

    @Test func diskBytesFallsBackToDuration() {
        #expect(song("a", bytes: 5_000_000).diskBytes == 5_000_000)
        #expect(song("b", duration: 100, bytes: 0).diskBytes == 3_200_000)
    }
}

@Suite struct UpdateCheckTests {
    @Test func compareVersions() {
        #expect(UpdateCheck.isNewer("1.0.1", than: "1.0.0"))
        #expect(UpdateCheck.isNewer("1.10", than: "1.9"))
        #expect(UpdateCheck.isNewer("2", than: "1.9.9"))
        #expect(!UpdateCheck.isNewer("1.0", than: "1.0.0"))
        #expect(!UpdateCheck.isNewer("1.0.0", than: "1.0.0"))
        #expect(!UpdateCheck.isNewer("0.9", than: "1.0"))
    }
}

@Suite struct SavedStateTests {
    @Test func oldOrPartialStateFileStillLoads() throws {
        let json = #"{"hasConnected":true,"pendingDelete":["x"],"kept":{}}"#
        let state = try JSONDecoder().decode(SavedState.self, from: Data(json.utf8))
        #expect(state.hasConnected)
        #expect(state.pendingDelete == ["x"])
        #expect(state.clipsEnabled)
        #expect(state.clipSeconds == 15)
        #expect(state.sessionSize == 20)
        #expect(state.checkUpdates)
    }

    @Test func emptyObjectGivesDefaults() throws {
        let state = try JSONDecoder().decode(SavedState.self, from: Data("{}".utf8))
        #expect(!state.hasConnected)
        #expect(state.appearance == "system")
    }

    @Test func roundTrip() throws {
        var state = SavedState()
        state.kept["a"] = now
        state.secondChance["b"] = ChanceEntry(added: now, playsWhenAdded: 3, skipsWhenAdded: 1, round: 2)
        state.pendingDelete = ["c", "d"]
        state.swapDirections = true
        state.dismissedUpdate = "1.2"
        let back = try JSONDecoder().decode(SavedState.self, from: JSONEncoder().encode(state))
        #expect(back.kept == state.kept)
        #expect(back.secondChance == state.secondChance)
        #expect(back.pendingDelete == state.pendingDelete)
        #expect(back.swapDirections)
        #expect(back.dismissedUpdate == "1.2")
    }
}

@Suite struct DecodeTests {
    @Test func decodesMusicOutput() throws {
        let json = #"""
        [{"id":"ABC","title":"T","artist":"","album":"","duration":201.5,"bytes":0,"playCount":0,"skipCount":1,
          "lastPlayed":null,"dateAdded":"2023-08-10T10:05:24.000Z"},
         {"id":"DEF","title":"U","artist":"A","album":"B","duration":0,"bytes":9,"playCount":3,"skipCount":0,
          "lastPlayed":"2024-01-01T00:00:00Z","dateAdded":null}]
        """#
        let songs = try MusicLibrary.decodeSongs(json)
        #expect(songs.count == 2)
        #expect(songs[0].lastPlayed == nil)
        #expect(songs[0].dateAdded != nil)
        #expect(songs[1].lastPlayed != nil)
        #expect(try MusicLibrary.decodeSongs("[]").isEmpty)
    }

    /// Set SIFT_LIBRARY_JSON to a file saved from Scripts.loadSongs to check a real library decodes.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["SIFT_LIBRARY_JSON"] != nil))
    func decodesRealLibrary() throws {
        let path = ProcessInfo.processInfo.environment["SIFT_LIBRARY_JSON"]!
        let songs = try MusicLibrary.decodeSongs(String(contentsOfFile: path, encoding: .utf8))
        #expect(!songs.isEmpty)
        let queue = Scoring.queue(from: songs, state: SavedState(), filter: .smart, limit: 20)
        #expect(queue.count == min(20, songs.filter { Scoring.isEligible($0, state: SavedState()) }.count))
    }
}

@Suite struct BackupTests {
    @Test func writesQuotedCSVAndNeverOverwrites() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("sift-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let tricky = Song(id: "1", title: #"Hello, "World""#, artist: "A, B", album: "", duration: 1, bytes: 0,
                          playCount: 2, skipCount: 0, lastPlayed: nil, dateAdded: nil)
        let first = try Backup.write([tricky], in: dir)
        let text = try String(contentsOf: first, encoding: .utf8)
        let lines = text.components(separatedBy: "\n")
        #expect(lines.count == 2)
        #expect(lines[1] == #""Hello, ""World""","A, B","","2","0","","""#)

        let second = try Backup.write([tricky], in: dir)
        #expect(first != second)
        #expect(FileManager.default.fileExists(atPath: first.path))
    }
}
