// Renders the app icon from LogoDrawing. Run scripts/make-icon.sh instead of this directly.
import AppKit
import SwiftUI

@MainActor
func render(pixels: Int, to url: URL) {
    let side = CGFloat(pixels)
    // macOS icons keep the tile at 80% of the canvas, leaving room for the shadow.
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
    renderer.scale = 1
    guard let image = renderer.cgImage else { fatalError("render failed") }
    let rep = NSBitmapImageRep(cgImage: image)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

MainActor.assumeIsolated {
    let out = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    try! FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    let sizes: [(String, Int)] = [
        ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
        ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
        ("icon_512x512", 512), ("icon_512x512@2x", 1024)
    ]
    for (name, pixels) in sizes { render(pixels: pixels, to: out.appendingPathComponent("\(name).png")) }
}
