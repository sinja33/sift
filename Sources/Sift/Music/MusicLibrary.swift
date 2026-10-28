import Foundation

struct Song: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let duration: Double
    let playCount: Int
    let skipCount: Int
    let lastPlayed: Date?
    let dateAdded: Date?
}

/// Talks to the Music app. Reading play counts and deleting songs only works through
/// Music's scripting interface, which is why Sift is a Mac app.
struct MusicLibrary {
    static let secondChancePlaylist = "Second Chance"

    func loadSongs() async throws -> [Song] {
        let json = try await Osa.run(Scripts.loadSongs)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFraction.date(from: text) ?? ISO8601DateFormatter().date(from: text) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unreadable date \(text)")
        }
        return try decoder.decode([Song].self, from: Data(json.utf8))
    }

    func play(id: String, from seconds: Double) async throws {
        _ = try await Osa.run(Scripts.play, args: [id, String(seconds)])
    }

    func pause() async throws {
        _ = try await Osa.run(Scripts.pause)
    }

    /// Deletes the songs from the library. Returns how many were deleted.
    func delete(ids: [String]) async throws -> Int {
        let result = try await Osa.run(Scripts.delete, args: [Self.json(ids)])
        return Int(result) ?? 0
    }

    func addToPlaylist(ids: [String], named name: String) async throws {
        _ = try await Osa.run(Scripts.addToPlaylist, args: [name, Self.json(ids)])
    }

    func removeFromPlaylist(ids: [String], named name: String) async throws {
        _ = try await Osa.run(Scripts.removeFromPlaylist, args: [name, Self.json(ids)])
    }

    /// Saves the song's artwork to a temporary file and returns its URL, or nil when the song has none.
    func artworkFile(id: String) async throws -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sift-art-\(id)")
        if FileManager.default.fileExists(atPath: url.path) { return url }
        let result = try await Osa.run(Scripts.artwork, language: .appleScript, args: [id, url.path])
        return result == "ok" ? url : nil
    }

    static func friendlyMessage(for error: Error) -> String {
        let text = error.localizedDescription
        if text.contains("-1743") {
            return "Sift isn't allowed to control Music. Open System Settings, go to Privacy & Security → Automation, and turn on Music under Sift."
        }
        if text.contains("-600") || text.contains("-609") {
            return "Sift couldn't reach the Music app. Open Music and try again."
        }
        return text.isEmpty ? "Something went wrong talking to Music." : text
    }

    private static func json(_ ids: [String]) -> String {
        let data = (try? JSONEncoder().encode(ids)) ?? Data("[]".utf8)
        return String(decoding: data, as: UTF8.self)
    }
}
