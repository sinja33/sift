// Draws the picture behind the install window of the disk image: a headline, an arrow from Sift to
// the Applications folder, and a hint for the first launch. Run by scripts/make-dmg-background.sh.
//   swift background.swift <output.png> <scale>
import AppKit

let width: CGFloat = 640, height: CGFloat = 400
/// Where Finder puts the two icons (their centres, measured from the top). Keep in sync with dmg-settings.py.
let appX: CGFloat = 175, appsX: CGFloat = 465, iconY: CGFloat = 215

let args = CommandLine.arguments
let out = URL(fileURLWithPath: args[1])
let scale = CGFloat(Double(args[2]) ?? 1)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: width, height: height)
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}
/// Finder measures from the top; Core Graphics from the bottom.
func flip(_ y: CGFloat) -> CGFloat { height - y }

// A mid-tone purple, so Finder's icon labels read in both light mode (black) and dark mode (white).
let gradient = NSGradient(colors: [color(0x8C96FF), color(0x6873F4)])!
gradient.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: -90)

// Soft light behind each icon.
for x in [appX, appsX] {
    let glow = NSGradient(colors: [color(0xFFFFFF, 0.30), color(0xFFFFFF, 0)])!
    glow.draw(fromCenter: NSPoint(x: x, y: flip(iconY)), radius: 0, toCenter: NSPoint(x: x, y: flip(iconY)), radius: 95, options: [])
}

// A dashed arrow arching from Sift to Applications.
let start = NSPoint(x: appX + 80, y: flip(iconY))
let end = NSPoint(x: appsX - 82, y: flip(iconY))
let arc = NSBezierPath()
arc.move(to: start)
arc.curve(to: end, controlPoint1: NSPoint(x: start.x + 40, y: flip(iconY) + 34), controlPoint2: NSPoint(x: end.x - 40, y: flip(iconY) + 34))
arc.lineWidth = 4
arc.lineCapStyle = .round
arc.setLineDash([1, 11], count: 2, phase: 0)
color(0xFFFFFF, 0.95).setStroke()
arc.stroke()

// Arrowhead, pointing along the end of the curve.
ctx.saveGState()
ctx.translateBy(x: end.x, y: end.y)
ctx.rotate(by: -0.62)
let head = NSBezierPath()
head.move(to: NSPoint(x: -15, y: 10))
head.line(to: NSPoint(x: 1, y: 0))
head.line(to: NSPoint(x: -15, y: -10))
head.lineWidth = 4.5
head.lineCapStyle = .round
head.lineJoinStyle = .round
head.stroke()
ctx.restoreGState()

func text(_ string: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat, top: CGFloat) {
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color(0xFFFFFF, alpha),
        .paragraphStyle: style,
    ]
    let lineHeight = size * 1.3
    NSAttributedString(string: string, attributes: attributes)
        .draw(in: NSRect(x: 20, y: flip(top) - lineHeight, width: width - 40, height: lineHeight))
}

text("Drag Sift into Applications", size: 26, weight: .heavy, alpha: 1, top: 38)
text("Then open it from your Applications folder.", size: 14, weight: .medium, alpha: 0.85, top: 76)
text("First time only: if your Mac says it can't verify Sift, click Done, then open", size: 12, weight: .medium, alpha: 0.85, top: 336)
text("System Settings → Privacy & Security, scroll down and click Open Anyway.", size: 12, weight: .medium, alpha: 0.85, top: 354)

NSGraphicsContext.current = nil
try rep.representation(using: .png, properties: [:])!.write(to: out)
