import AppKit
import SwiftUI

@main
struct SiftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        Window("Sift", id: "main") {
            RootView()
                .environment(model)
        }
        .windowResizability(.contentMinSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when started with `swift run`, which has no app bundle.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") == nil { setDevIcon() }
    }

    /// Draws the Dock icon for runs without a bundle; the built app ships Support/AppIcon.icns.
    @MainActor private func setDevIcon() {
        let side: CGFloat = 512
        let view = Canvas { context, size in
            let tile = size.width * 0.8
            let rect = CGRect(x: (size.width - tile) / 2, y: (size.height - tile) / 2, width: tile, height: tile)
            var shadow = context
            shadow.addFilter(.shadow(color: .black.opacity(0.25), radius: side * 0.012, x: 0, y: side * 0.01))
            shadow.fill(Path(roundedRect: rect, cornerRadius: tile * 26 / 96, style: .continuous), with: .color(.black))
            LogoDrawing.draw(in: &context, rect: rect)
        }
        .frame(width: side, height: side)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        if let image = renderer.nsImage { NSApp.applicationIconImage = image }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
