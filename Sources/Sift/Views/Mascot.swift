import SwiftUI

/// The card character that cheers you on during a session, drawn on a 120 x 120 grid.
struct Mascot: View {
    enum Mood: CaseIterable { case happy, sparkle, wink, heart, cheer }
    let mood: Mood
    var size: CGFloat = 120
    @Environment(\.colorScheme) private var scheme

    private static let ink = Color(red: 0x15 / 255, green: 0x17 / 255, blue: 0x2A / 255)
    private static let blush = Color(red: 1, green: 0xB7 / 255, blue: 0xC5 / 255)

    var body: some View {
        // Outlines sit on the page, so they flip to light in dark mode. Faces stay dark on the white card.
        let outline = scheme == .dark ? Color(red: 0xEC / 255, green: 0xEE / 255, blue: 0xFA / 255) : Self.ink
        return Canvas { context, canvas in
            let s = canvas.width / 120
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, fill: Color, degrees: Double = 0, pivot: CGPoint = .zero) {
                var path = Path(roundedRect: CGRect(x: x * s, y: y * s, width: w * s, height: h * s), cornerRadius: r * s, style: .continuous)
                if degrees != 0 {
                    let t = CGAffineTransform(translationX: pivot.x * s, y: pivot.y * s)
                        .rotated(by: degrees * .pi / 180)
                        .translatedBy(x: -pivot.x * s, y: -pivot.y * s)
                    path = path.applying(t)
                }
                context.fill(path, with: .color(fill))
                context.stroke(path, with: .color(outline), style: StrokeStyle(lineWidth: 2.6 * s, lineJoin: .round))
            }
            func dot(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ color: Color) {
                context.fill(Path(ellipseIn: CGRect(x: (x - r) * s, y: (y - r) * s, width: 2 * r * s, height: 2 * r * s)), with: .color(color))
            }
            func line(_ from: CGPoint, _ to: CGPoint, width: CGFloat) {
                var path = Path(); path.move(to: from); path.addLine(to: to)
                context.stroke(path, with: .color(outline), style: StrokeStyle(lineWidth: width * s, lineCap: .round))
            }
            func smile(from: CGPoint, to: CGPoint, control: CGPoint) {
                var path = Path(); path.move(to: from); path.addQuadCurve(to: to, control: control)
                context.stroke(path, with: .color(Self.ink), style: StrokeStyle(lineWidth: 2.8 * s, lineCap: .round))
            }

            rect(22, 14, 52, 70, 10, fill: Color(red: 0x9A / 255, green: 0xA6 / 255, blue: 1), degrees: -18, pivot: CGPoint(x: 48, y: 49))
            rect(46, 22, 52, 70, 10, fill: Color(red: 0xD3 / 255, green: 0xD8 / 255, blue: 1), degrees: 16, pivot: CGPoint(x: 72, y: 57))
            rect(34, 26, 56, 76, 11, fill: .white)

            func blush(_ y: CGFloat) {
                for x: CGFloat in [41, 73] {
                    context.fill(Path(ellipseIn: CGRect(x: x * s, y: y * s, width: 10 * s, height: 6.4 * s)), with: .color(Self.blush))
                }
            }
            func star(_ cx: CGFloat, _ cy: CGFloat, _ color: Color) {
                var star = Path()
                star.move(to: p(cx, cy - 6)); star.addLine(to: p(cx + 2, cy - 1)); star.addLine(to: p(cx + 7, cy + 1))
                star.addLine(to: p(cx + 2, cy + 3)); star.addLine(to: p(cx, cy + 8)); star.addLine(to: p(cx - 2, cy + 3))
                star.addLine(to: p(cx - 7, cy + 1)); star.addLine(to: p(cx - 2, cy - 1)); star.closeSubpath()
                context.fill(star, with: .color(color))
                context.stroke(star, with: .color(Self.ink), style: StrokeStyle(lineWidth: 1.6 * s, lineJoin: .round))
            }
            func heart(_ cx: CGFloat, _ cy: CGFloat) {
                var h = Path()
                h.move(to: p(cx, cy + 7))
                h.addCurve(to: p(cx - 7, cy - 1), control1: p(cx - 3, cy + 5), control2: p(cx - 7, cy + 2))
                h.addCurve(to: p(cx, cy - 2), control1: p(cx - 7, cy - 6), control2: p(cx - 2, cy - 6))
                h.addCurve(to: p(cx + 7, cy - 1), control1: p(cx + 2, cy - 6), control2: p(cx + 7, cy - 6))
                h.addCurve(to: p(cx, cy + 7), control1: p(cx + 7, cy + 2), control2: p(cx + 3, cy + 5))
                context.fill(h, with: .color(Color.hex(0xE0424A)))
                context.stroke(h, with: .color(Self.ink), style: StrokeStyle(lineWidth: 1.6 * s, lineJoin: .round))
            }
            func openMouth(_ y: CGFloat) {
                var mouth = Path()
                mouth.move(to: p(52, y)); mouth.addQuadCurve(to: p(72, y), control: p(62, y + 28)); mouth.closeSubpath()
                context.fill(mouth, with: .color(Self.ink))
                context.stroke(mouth, with: .color(Self.ink), style: StrokeStyle(lineWidth: 2 * s, lineJoin: .round))
            }
            func arms() { line(p(34, 66), p(20, 46), width: 3); line(p(90, 66), p(104, 46), width: 3) }

            switch mood {
            case .happy:
                smile(from: p(47, 59), to: p(59, 59), control: p(53, 52))
                smile(from: p(65, 59), to: p(77, 59), control: p(71, 52))
                blush(66); openMouth(68); arms()
            case .sparkle:
                star(55, 58, Color.hex(0xE39E12)); star(73, 58, Color.hex(0xE39E12))
                blush(68); smile(from: p(53, 71), to: p(71, 71), control: p(62, 79)); arms()
            case .wink:
                dot(53, 59, 4, Self.ink)
                smile(from: p(66, 60), to: p(78, 60), control: p(72, 53))
                blush(67); smile(from: p(52, 70), to: p(74, 70), control: p(65, 80))
                line(p(90, 66), p(104, 46), width: 3); line(p(34, 70), p(24, 82), width: 3)
            case .heart:
                heart(55, 58); heart(73, 58)
                blush(68); smile(from: p(54, 71), to: p(70, 71), control: p(62, 78)); arms()
            case .cheer:
                smile(from: p(47, 60), to: p(59, 60), control: p(53, 52))
                smile(from: p(65, 60), to: p(77, 60), control: p(71, 52))
                blush(66); openMouth(68)
                line(p(34, 64), p(16, 34), width: 3); line(p(90, 64), p(108, 34), width: 3)
            }
            dot(12, 24, 4, Color.hex(0xE39E12)); dot(106, 16, 3.6, Color.hex(0xE0424A))
            dot(112, 62, 3.2, Color.hex(0x2FC68C)); dot(8, 64, 3.2, Color.hex(0x3B4CF5))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Cheering card mascot")
    }
}
