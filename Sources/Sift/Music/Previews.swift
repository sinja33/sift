import AVFoundation

/// Short previews of songs from Apple's public iTunes Search, used to play the clips. They are small files
/// kept in the caches folder, so nothing is downloaded into your Music library, and the songs get no extra plays.
/// Only the artist and title are sent. Songs without a preview are played through Music instead.
enum Previews {
    private struct Response: Decodable {
        struct Item: Decodable {
            let artistName: String?
            let trackName: String?
            let previewUrl: String?
        }
        let results: [Item]
    }

    /// Songs known to have no preview, so they are not searched for again.
    private static let misses = Misses()

    private final class Misses: @unchecked Sendable {
        private let lock = NSLock()
        private var ids: Set<String> = []
        func contains(_ id: String) -> Bool { lock.lock(); defer { lock.unlock() }; return ids.contains(id) }
        func insert(_ id: String) { lock.lock(); defer { lock.unlock() }; ids.insert(id) }
    }

    /// The preview's audio file, fetched first if it is not already kept. Nil when the song has no preview.
    static func file(for song: Song) async -> URL? {
        let file = cacheFile(for: song)
        if FileManager.default.fileExists(atPath: file.path) { return file }
        if misses.contains(song.id) { return nil }

        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: "\(song.artist) \(song.title)"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "5")
        ]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        // A failed search (no network) is not remembered, so it is tried again later.
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let response = try? JSONDecoder().decode(Response.self, from: data) else { return nil }

        let artist = CoverLookup.plain(song.artist), title = CoverLookup.plain(song.title)
        guard !title.isEmpty,
              let match = response.results.first(where: { item in
                  let a = CoverLookup.plain(item.artistName ?? ""), t = CoverLookup.plain(item.trackName ?? "")
                  return item.previewUrl != nil && !t.isEmpty && (t.contains(title) || title.contains(t))
                      && (a.contains(artist) || artist.contains(a) || artist.isEmpty)
              }),
              let audio = match.previewUrl.flatMap(URL.init(string:)) else {
            misses.insert(song.id)
            return nil
        }
        var audioRequest = URLRequest(url: audio)
        audioRequest.timeoutInterval = 8
        guard let (bytes, _) = try? await URLSession.shared.data(for: audioRequest), !bytes.isEmpty else { return nil }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Written in one piece, so a play that starts meanwhile never sees half a file.
        try? bytes.write(to: file, options: .atomic)
        return file
    }

    /// Deletes previews that have not been touched for a few days, so the cache stays small.
    static func trim() {
        let dir = cacheFile(for: nil).deletingLastPathComponent()
        let cutoff = Date().addingTimeInterval(-3 * 86_400)
        for url in (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [] {
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let modified, modified < cutoff { try? FileManager.default.removeItem(at: url) }
        }
    }

    private static func cacheFile(for song: Song?) -> URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Sift/previews")
        return song.map { dir.appendingPathComponent("\($0.id).m4a") } ?? dir.appendingPathComponent("x")
    }
}

/// Plays one preview at a time.
@MainActor
final class ClipPlayer {
    private var player: AVAudioPlayer?

    func play(_ file: URL) throws {
        player?.stop()
        let next = try AVAudioPlayer(contentsOf: file)
        next.prepareToPlay()
        next.play()
        player = next
    }

    func stop() {
        player?.stop()
        player = nil
    }
}
