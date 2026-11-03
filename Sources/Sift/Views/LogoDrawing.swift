import SwiftUI

/// The Sift mark, drawn on a 96 x 96 grid: a midnight tile with a straight stack of three cards, the
/// front one carrying a music note. Shared by the in-app logo and scripts/icon, which renders the app icon.
enum LogoDrawing {
    private static let ink = Color(red: 0x15 / 255, green: 0x17 / 255, blue: 0x2A / 255)

    /// Draws the mark filling `rect`. Without the tile only the cards are drawn, outlined in `outline`.
    static func draw(in context: inout GraphicsContext, rect: CGRect, tile showsTile: Bool = true, outline: Color? = nil) {
        let edge = outline ?? ink
        let s = rect.width / 96

        // Tile, a diagonal blend from a lifted blue-black to ink.
        if showsTile {
            let tile = Path(roundedRect: rect, cornerRadius: 26 * s, style: .continuous)
            context.fill(tile, with: .linearGradient(
                Gradient(colors: [Color(red: 0x2A / 255, green: 0x2D / 255, blue: 0x5A / 255), ink]),
                startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
        }

        // The stack is laid out around (54, 48), then moved to the centre of the grid and enlarged by 10%.
        let k: CGFloat = 1.1
        func map(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + (48 + (x - 54) * k) * s, y: rect.minY + (48 + (y - 48) * k) * s)
        }
        func card(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, fill: Color) {
            let origin = map(x, y)
            let path = Path(roundedRect: CGRect(x: origin.x, y: origin.y, width: width * k * s, height: height * k * s),
                            cornerRadius: 8 * k * s, style: .continuous)
            context.fill(path, with: .color(fill))
            context.stroke(path, with: .color(edge), style: StrokeStyle(lineWidth: 2.2 * k * s, lineJoin: .round))
        }

        card(x: 40, y: 14, width: 42, height: 54, fill: Color(red: 0xC5 / 255, green: 0xCB / 255, blue: 1))
        card(x: 34, y: 19, width: 42, height: 56, fill: Color(red: 0x73 / 255, green: 0x81 / 255, blue: 1))
        card(x: 26, y: 24, width: 44, height: 58, fill: .white)

        // Eighth note, from a 24 x 24 icon centred on the front card.
        let at = map(48, 53)
        let toTile = CGAffineTransform(translationX: at.x, y: at.y)
            .scaledBy(x: 1.45 * k * s, y: 1.45 * k * s)
            .translatedBy(x: -12, y: -12)
        context.fill(note.applying(toTile), with: .color(ink))
    }

    private static let note: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 13.75, y: 2))
        p.addCurve(to: CGPoint(x: 13, y: 1.25), control1: CGPoint(x: 13.75, y: 1.58579), control2: CGPoint(x: 13.4142, y: 1.25))
        p.addCurve(to: CGPoint(x: 12.25, y: 2), control1: CGPoint(x: 12.5858, y: 1.25), control2: CGPoint(x: 12.25, y: 1.58579))
        p.addLine(to: CGPoint(x: 12.25, y: 14.5359))
        p.addCurve(to: CGPoint(x: 9, y: 13.25), control1: CGPoint(x: 11.4003, y: 13.7384), control2: CGPoint(x: 10.2572, y: 13.25))
        p.addCurve(to: CGPoint(x: 4.25, y: 18), control1: CGPoint(x: 6.37665, y: 13.25), control2: CGPoint(x: 4.25, y: 15.3766))
        p.addCurve(to: CGPoint(x: 9, y: 22.75), control1: CGPoint(x: 4.25, y: 20.6234), control2: CGPoint(x: 6.37665, y: 22.75))
        p.addCurve(to: CGPoint(x: 13.75, y: 18), control1: CGPoint(x: 11.6234, y: 22.75), control2: CGPoint(x: 13.75, y: 20.6234))
        p.addLine(to: CGPoint(x: 13.75, y: 6.243))
        p.addCurve(to: CGPoint(x: 19, y: 8.75), control1: CGPoint(x: 14.9875, y: 7.77225), control2: CGPoint(x: 16.8795, y: 8.75))
        p.addCurve(to: CGPoint(x: 19.75, y: 8), control1: CGPoint(x: 19.4142, y: 8.75), control2: CGPoint(x: 19.75, y: 8.41421))
        p.addCurve(to: CGPoint(x: 19, y: 7.25), control1: CGPoint(x: 19.75, y: 7.58579), control2: CGPoint(x: 19.4142, y: 7.25))
        p.addCurve(to: CGPoint(x: 13.75, y: 2), control1: CGPoint(x: 16.1005, y: 7.25), control2: CGPoint(x: 13.75, y: 4.8995))
        p.closeSubpath()
        return p
    }()
}
