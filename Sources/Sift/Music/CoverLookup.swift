import AppKit

/// Finds cover art for songs Music has none for, using Apple's public iTunes Search. It needs no account.
/// The artist and title are sent, nothing else about your library. Covers are kept in the caches folder.
enum CoverLookup {
    private struct Response: Decodable {
        struct Item: Decodable {
            let artistName: String?
            let trackName: String?
            let artworkUrl100: String?
        }
        let results: [Item]
    }

    static func fetch(_ song: Song) async -> NSImage? {
        let file = cacheFile(for: song)
        if let data = try? Data(contentsOf: file), let image = NSImage(data: data) { return image }

        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: "\(song.artist) \(song.title)"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "5")
        ]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let response = try? JSONDecoder().decode(Response.self, from: data) else { return nil }

        // Only accept a result for the same song, so a different cover is never shown.
        let artist = plain(song.artist), title = plain(song.title)
        guard !title.isEmpty,
              let match = response.results.first(where: { item in
                  let a = plain(item.artistName ?? ""), t = plain(item.trackName ?? "")
                  return !t.isEmpty && (t.contains(title) || title.contains(t)) && (a.contains(artist) || artist.contains(a) || artist.isEmpty)
              }),
              let art = match.artworkUrl100?.replacingOccurrences(of: "100x100bb", with: "600x600bb"),
              let artURL = URL(string: art) else { return nil }
        var artRequest = URLRequest(url: artURL)
        artRequest.timeoutInterval = 8
        guard let (bytes, _) = try? await URLSession.shared.data(for: artRequest),
              let image = NSImage(data: bytes) else { return nil }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? bytes.write(to: file)
        return image
    }

    /// Lowercase letters and digits only, so punctuation and spacing differences do not matter.
    private static func plain(_ text: String) -> String {
        String(text.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }

    private static func cacheFile(for song: Song) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sift/covers/\(song.id).jpg")
    }
}
