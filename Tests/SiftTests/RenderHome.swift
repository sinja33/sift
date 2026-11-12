import AppKit
import SwiftUI
import Testing
@testable import Sift

/// Renders the Home screen at a few window widths to PNGs, for checking the layout by eye.
/// Set SIFT_RENDER_DIR to a folder (and optionally SIFT_LIBRARY_JSON to a saved library) to run it.
@MainActor
@Test(.enabled(if: ProcessInfo.processInfo.environment["SIFT_RENDER_DIR"] != nil))
func renderHome() async throws {
    let env = ProcessInfo.processInfo.environment
    let out = URL(fileURLWithPath: env["SIFT_RENDER_DIR"]!)
    let model = AppModel()
    model.state.clipsEnabled = false
    if let path = env["SIFT_LIBRARY_JSON"] {
        model.songs = try MusicLibrary.decodeSongs(String(contentsOfFile: path, encoding: .utf8))
    }
    // Swiping saves to the real state file, so keep a copy and put it back when done.
    let stateFile = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Sift/state.json")
    let savedState = try? Data(contentsOf: stateFile)
    defer { if let savedState { try? savedState.write(to: stateFile, options: .atomic) } }
    if env["SIFT_RENDER_MIDSESSION"] != nil {
        // Leave a session part-way through after marking three songs for deletion.
        model.startSession()
        model.stopClip()
        for _ in 0..<3 { model.decide(.delete) }
        model.decide(.keep)
        model.endSession()
    }
    let swipe = env["SIFT_RENDER_SWIPE"] != nil
    if swipe { model.resume(.swipe) } else { model.screen = .home }
    model.state.checkUpdates = false
    model.ensureSpotlight()
    for width in swipe ? [760, 960, 1200] : [640, 760, 900, 1000, 1200] {
        let screen = swipe ? AnyView(SwipeView()) : AnyView(HomeView())
        let host = NSHostingView(rootView: screen.environment(model).foregroundStyle(Theme.ink).background(Theme.paper))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 760), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        window.orderFront(nil)
        try await Task.sleep(for: .seconds(2))
        let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
        host.cacheDisplay(in: host.bounds, to: rep)
        try rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent("\(swipe ? "swipe" : "home")-\(width).png"))
        window.orderOut(nil)
    }
}
