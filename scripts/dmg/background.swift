// Draws the picture behind the install window of the disk image: a headline, a music staff whose lines
// end in an arrow from Sift to the Applications folder, and a hint for the first launch.
// The design comes from the "Sift Install Window" canvas (option C). Positions are in points from the
// top-left of the 640 × 337 window, the same numbers as on the canvas.
// Run by scripts/make-dmg-background.sh:   swift background.swift <output.png> <scale>
import AppKit

/// The design is 640 × 337. The picture runs a little taller, continuing the gradient, so a taller title bar
/// on some Macs never leaves a gap at the bottom of the window.
let width: CGFloat = 640, designHeight: CGFloat = 337, height: CGFloat = 365

let args = CommandLine.arguments
let out = URL(fileURLWithPath: args[1])
let scale = CGFloat(Double(args[2]) ?? 1)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: width, height: height)
let cg = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
// Draw with the origin at the top-left, like the canvas, so every number below matches it.
cg.translateBy(x: 0, y: height)
cg.scaleBy(x: 1, y: -1)
NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}
let white = NSColor.white

// Background: a vertical gradient. Mid-tone, so Finder's icon labels read in light and dark mode.
let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [color(0x8A94FF).cgColor, color(0x4954DE).cgColor] as CFArray, locations: [0, 1])!
cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: designHeight), options: [.drawsAfterEndLocation])

/// Text in a box like a CSS line box: the glyphs are centred vertically in `lineHeight`.
func text(_ string: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat, left: CGFloat, top: CGFloat, lineHeight: CGFloat) {
    let font = NSFont.systemFont(ofSize: size, weight: weight)
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let natural = font.ascender - font.descender
    NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: white.withAlphaComponent(alpha), .paragraphStyle: style])
        .draw(in: NSRect(x: left, y: top + (lineHeight - natural) / 2, width: 600, height: natural + 2))
}

/// Runs `body` in an SVG-like box: content in `viewBox` units, scaled to fit the box and centred, as a browser does.
func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, viewBox vb: CGRect, opacity: CGFloat = 1, _ body: () -> Void) {
    let s = min(w / vb.width, h / vb.height)
    cg.saveGState()
    cg.setAlpha(opacity)
    cg.beginTransparencyLayer(auxiliaryInfo: nil)
    cg.translateBy(x: x + (w - vb.width * s) / 2 - vb.minX * s, y: y + (h - vb.height * s) / 2 - vb.minY * s)
    cg.scaleBy(x: s, y: s)
    body()
    cg.endTransparencyLayer()
    cg.restoreGState()
}

// The parts of a note, in the canvas's 16 × 26 (single) and 26 × 34 (pair) note drawings.
func head(_ cx: CGFloat, _ cy: CGFloat) {
    cg.saveGState()
    cg.translateBy(x: cx, y: cy)
    cg.rotate(by: -20 * .pi / 180)
    cg.setFillColor(white.cgColor)
    cg.fillEllipse(in: CGRect(x: -4.2, y: -3, width: 8.4, height: 6))
    cg.restoreGState()
}
func stroke(_ points: [CGPoint], width: CGFloat, round: Bool = false) {
    cg.setStrokeColor(white.cgColor)
    cg.setLineWidth(width)
    cg.setLineCap(round ? .round : .butt)
    cg.setLineJoin(.round)
    cg.addLines(between: points)
    cg.strokePath()
}
func singleNote(flag: Bool) {
    head(5, 22)
    stroke([CGPoint(x: 8.6, y: 21), CGPoint(x: 8.6, y: 3)], width: 1.4)
    if flag {
        cg.setStrokeColor(white.cgColor)
        cg.setLineWidth(1.6)
        cg.setLineCap(.round)
        cg.move(to: CGPoint(x: 8.6, y: 3))
        cg.addCurve(to: CGPoint(x: 12.6, y: 14), control1: CGPoint(x: 9.4, y: 7), control2: CGPoint(x: 14.5, y: 8))
        cg.strokePath()
    }
}
func notePair() {
    head(5, 29)
    head(18, 22)
    stroke([CGPoint(x: 8.6, y: 28), CGPoint(x: 8.6, y: 10)], width: 1.4)
    stroke([CGPoint(x: 21.6, y: 21), CGPoint(x: 21.6, y: 4)], width: 1.4)
    cg.setFillColor(white.cgColor)
    cg.addLines(between: [CGPoint(x: 7.9, y: 8.6), CGPoint(x: 22.3, y: 2.4), CGPoint(x: 22.3, y: 5.6), CGPoint(x: 7.9, y: 11.8)])
    cg.closePath()
    cg.fillPath()
}
let single = CGRect(x: 0, y: 0, width: 16, height: 26)
let pair = CGRect(x: 0, y: 0, width: 26, height: 34)

// Headline and subline.
text("Drag Sift into Applications", size: 26, weight: .heavy, alpha: 1, left: 22, top: 24, lineHeight: 34)
text("Then open it from your Applications folder.", size: 14, weight: .medium, alpha: 0.85, left: 22, top: 66, lineHeight: 18)

// The five staff lines: the outer ones stop first, the middle one runs furthest, like an arrow.
for (top, length, thickness) in [(159.0, 140.0, 1.4), (166, 150, 1.4), (173, 160, 1.6), (180, 150, 1.4), (187, 140, 1.4)] as [(CGFloat, CGFloat, CGFloat)] {
    white.withAlphaComponent(0.9).setFill()
    NSBezierPath(roundedRect: NSRect(x: 234, y: top, width: length, height: thickness), xRadius: 1, yRadius: 1).fill()
}

// Treble clef, centred on x = 246.5 with its baseline at y = 187.3, where the canvas puts it.
let clefFont = NSFont(name: "Apple Symbols", size: 52 * 71.0 / 68.0) ?? NSFont.systemFont(ofSize: 54)
let clef = NSAttributedString(string: "\u{1D11E}", attributes: [.font: clefFont, .foregroundColor: white])
clef.draw(at: NSPoint(x: 246.5 - clef.size().width / 2, y: 187.3 - clefFont.ascender))

// Notes, fading out towards the Applications folder.
box(308, 164, 12, 19, viewBox: single, opacity: 0.75 * 0.9) { singleNote(flag: true) }
box(261, 163, 13, 21, viewBox: single, opacity: 1) { singleNote(flag: true) }
box(298, 150, 13, 20, viewBox: single, opacity: 0.8) { singleNote(flag: false) }
box(274, 166, 21, 25, viewBox: pair, opacity: 0.85) { notePair() }
box(326, 150, 21, 25, viewBox: pair, opacity: 0.6) { notePair() }
box(345, 170, 13, 21, viewBox: single, opacity: 0.4) { singleNote(flag: false) }
box(362, 163, 13, 21, viewBox: single, opacity: 0.25) { singleNote(flag: true) }

// Arrowhead past the end of the staff.
box(388, 160, 18, 27, viewBox: CGRect(x: 368, y: 147, width: 42, height: 54), opacity: 0.9) {
    stroke([CGPoint(x: 373, y: 152), CGPoint(x: 404, y: 173.8), CGPoint(x: 373, y: 195.6)], width: 4, round: true)
}

// Finder always draws the icon names in black over a picture, so each name gets a soft light pill behind it.
// Sized and placed to where Finder puts "Sift" and "Applications" under 112-point icons.
for pill in [NSRect(x: 154, y: 237.5, width: 42, height: 22), NSRect(x: 416.5, y: 237.5, width: 101, height: 22)] {
    white.withAlphaComponent(0.9).setFill()
    NSBezierPath(roundedRect: pill, xRadius: 11, yRadius: 11).fill()
}

// First-launch hint.
text("First time only: if your Mac says it can't verify Sift, click Done, then open", size: 12, weight: .medium, alpha: 0.85, left: 23, top: 279, lineHeight: 18)
text("System Settings → Privacy & Security, scroll down and click Open Anyway.", size: 12, weight: .medium, alpha: 0.85, left: 23, top: 297, lineHeight: 18)

NSGraphicsContext.current = nil
try rep.representation(using: .png, properties: [:])!.write(to: out)
