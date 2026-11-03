import AppKit

/// Looks up an artist's photo on Deezer's public search, which needs no account. Music's scripting
/// interface has no artist pictures. Only the artist's name is sent, and photos are kept in the caches folder.
enum ArtistImages {
    private struct Response: Decodable {
        struct Artist: Decodable {
            let name: String
            let pictureBig: String?
            enum CodingKeys: String, CodingKey { case name, pictureBig = "picture_big" }
        }
        let data: [Artist]
    }

    static func fetch(_ artist: String) async -> NSImage? {
        let file = cacheFile(for: artist)
        if let data = try? Data(contentsOf: file), let image = NSImage(data: data) { return image }

        var components = URLComponents(string: "https://api.deezer.com/search/artist")!
        components.queryItems = [URLQueryItem(name: "q", value: artist), URLQueryItem(name: "limit", value: "5")]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let response = try? JSONDecoder().decode(Response.self, from: data) else { return nil }

        // Only accept an exact name match, so a different artist's photo is never shown.
        let key = Scoring.artistKey(artist)
        guard let match = response.data.first(where: { Scoring.artistKey($0.name) == key }),
              let picture = match.pictureBig.flatMap(URL.init(string:)) else { return nil }
        var pictureRequest = URLRequest(url: picture)
        pictureRequest.timeoutInterval = 8
        guard let (bytes, _) = try? await URLSession.shared.data(for: pictureRequest),
              let image = NSImage(data: bytes) else { return nil }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? bytes.write(to: file)
        return image
    }

    private static func cacheFile(for artist: String) -> URL {
        let name = Data(Scoring.artistKey(artist).utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .prefix(120)
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sift/artists/\(name).jpg")
    }
}
