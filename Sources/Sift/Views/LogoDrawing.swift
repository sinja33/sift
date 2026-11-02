import SwiftUI

/// The Sift mark, drawn on a 96 x 96 grid: an indigo tile with two outlined cards behind a white
/// one that carries a music note. Shared by the in-app logo and scripts/icon, which renders the app icon.
enum LogoDrawing {
    private static let ink = Color(red: 0x15 / 255, green: 0x17 / 255, blue: 0x2A / 255)

    /// Draws the mark filling `rect`.
    static func draw(in context: inout GraphicsContext, rect: CGRect) {
        let s = rect.width / 96
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.minY + y * s) }

        // Tile, lighter in the middle and darker at the edges.
        let tile = Path(roundedRect: rect, cornerRadius: 26 * s, style: .continuous)
        let center = point(48, 43)
        context.fill(tile, with: .radialGradient(
            Gradient(stops: [
                .init(color: Color(red: 0x5F / 255, green: 0x6E / 255, blue: 1), location: 0),
                .init(color: Color(red: 0x3B / 255, green: 0x4C / 255, blue: 0xF5 / 255), location: 0.48),
                .init(color: Color(red: 0x22 / 255, green: 0x30 / 255, blue: 0xB8 / 255), location: 1)
            ]),
            center: center, startRadius: 0, endRadius: 71.4 * s))

        func card(x: CGFloat, y: CGFloat, width: CGFloat = 40, height: CGFloat = 54, fill: Color, degrees: Double = 0, pivot: (CGFloat, CGFloat) = (0, 0)) {
            var path = Path(roundedRect: CGRect(x: rect.minX + x * s, y: rect.minY + y * s, width: width * s, height: height * s),
                            cornerRadius: 8 * s, style: .continuous)
            if degrees != 0 {
                let p = point(pivot.0, pivot.1)
                let t = CGAffineTransform(translationX: p.x, y: p.y).rotated(by: degrees * .pi / 180).translatedBy(x: -p.x, y: -p.y)
                path = path.applying(t)
            }
            context.fill(path, with: .color(fill))
            context.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: 2.2 * s, lineJoin: .round))
        }

        card(x: 20, y: 14, fill: Color(red: 0x9A / 255, green: 0xA6 / 255, blue: 1), degrees: -24, pivot: (40, 41))
        card(x: 36, y: 31, fill: Color(red: 0xD3 / 255, green: 0xD8 / 255, blue: 1), degrees: 20, pivot: (56, 58))
        card(x: 28, y: 22, width: 42, height: 56, fill: .white)

        // Eighth note, from a 24 x 24 icon centred on the front card.
        let toTile = CGAffineTransform(translationX: rect.minX + 49 * s, y: rect.minY + 51 * s)
            .scaledBy(x: 1.65 * s, y: 1.65 * s)
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
