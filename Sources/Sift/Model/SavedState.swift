import Foundation

struct ChanceEntry: Codable, Hashable {
    var added: Date
    var playsWhenAdded: Int
    var skipsWhenAdded: Int
    var round: Int
}

/// Everything Sift remembers between launches. Stored as JSON in Application Support.
struct SavedState: Codable {
    var hasConnected = false
    /// Songs you kept, and when. They stay out of the queue for a while.
    var kept: [String: Date] = [:]
    /// Songs in the Second Chance playlist.
    var secondChance: [String: ChanceEntry] = [:]
    /// Songs you swiped away that are waiting on the review screen.
    var pendingDelete: [String] = []
    var removedCount = 0
    /// When true, swiping left keeps and swiping right deletes.
    var swapDirections = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hasConnected = try c.decodeIfPresent(Bool.self, forKey: .hasConnected) ?? false
        kept = try c.decodeIfPresent([String: Date].self, forKey: .kept) ?? [:]
        secondChance = try c.decodeIfPresent([String: ChanceEntry].self, forKey: .secondChance) ?? [:]
        pendingDelete = try c.decodeIfPresent([String].self, forKey: .pendingDelete) ?? []
        removedCount = try c.decodeIfPresent(Int.self, forKey: .removedCount) ?? 0
        swapDirections = try c.decodeIfPresent(Bool.self, forKey: .swapDirections) ?? false
    }
}

struct StateStore {
    private var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sift", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("state.json")
    }

    func load() -> SavedState {
        guard let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(SavedState.self, from: data) else { return SavedState() }
        return state
    }

    func save(_ state: SavedState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

/// Writes a CSV of deleted songs to ~/Documents/Sift Backups before anything is deleted.
enum Backup {
    @discardableResult
    static func write(_ songs: [Song]) throws -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sift Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd HH.mm"
        let url = dir.appendingPathComponent("Deleted \(stamp.string(from: Date())).csv")
        let iso = ISO8601DateFormatter()
        var lines = ["Title,Artist,Album,Plays,Skips,Date added,Last played"]
        for song in songs {
            let fields = [
                song.title, song.artist, song.album,
                String(song.playCount), String(song.skipCount),
                song.dateAdded.map { iso.string(from: $0) } ?? "",
                song.lastPlayed.map { iso.string(from: $0) } ?? ""
            ]
            lines.append(fields.map(quote).joined(separator: ","))
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func quote(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
