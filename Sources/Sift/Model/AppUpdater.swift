import AppKit
import Sparkle

/// Installs new versions from inside the app, through Sparkle. It reads the list of releases at `SUFeedURL`
/// (published with each GitHub release), checks the download is signed with Sift's key, swaps the app in
/// place and restarts it. A download made this way is not marked as "from the internet", so macOS does not
/// ask for "Open Anyway" again.
@MainActor
enum AppUpdater {
    /// Nil when running outside a built app (e.g. `swift run`), where there is nothing to replace.
    private static let controller: SPUStandardUpdaterController? = {
        guard Bundle.main.bundleURL.pathExtension == "app",
              Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil else { return nil }
        return SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }()

    static var isAvailable: Bool { controller != nil }

    /// Shows Sparkle's window: what is new, then Install and Relaunch.
    static func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
