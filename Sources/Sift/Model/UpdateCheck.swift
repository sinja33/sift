import Foundation

/// Asks GitHub whether a newer release of Sift exists. Nothing about you or your library is sent.
enum UpdateCheck {
    struct Release: Equatable {
        let version: String
        let url: URL
    }

    private static let endpoint = URL(string: "https://api.github.com/repos/sinja33/sift/releases/latest")!

    /// The version of the running app. Nil when running outside a built app (e.g. `swift run`).
    static var installed: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    /// The newest release when it is newer than the installed version.
    static func newerRelease() async -> Release? {
        guard let installed else { return nil }
        var request = URLRequest(url: endpoint, timeoutInterval: 8)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let page = (json["html_url"] as? String).flatMap(URL.init(string:)) else { return nil }
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        return isNewer(version, than: installed) ? Release(version: version, url: page) : nil
    }

    /// Compares dotted numbers, so 1.10 is newer than 1.9.
    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }
        let y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}
