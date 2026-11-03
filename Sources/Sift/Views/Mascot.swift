import SwiftUI

/// The card character that cheers you on, drawn on a 120 x 120 grid. It is the logo's straight stack of
/// three cards, with a face on the front one.
struct Mascot: View {
    enum Mood: CaseIterable { case happy, wink, cheer, sleepy, oops, wow }
    let mood: Mood
    var size: CGFloat = 120
    /// Bobs, waves and twinkles. Off by default so small uses stay still.
    var animated = false
    @Environment(\.colorScheme) private var scheme

    private static let ink = Color(red: 0x15 / 255, green: 0x17 / 255, blue: 0x2A / 255)
    private static let blush = Color(red: 1, green: 0xB7 / 255, blue: 0xC5 / 255)
    private static let gold = Color.hex(0xE39E12)

    var body: some View {
        // Outlines sit on the page, so they flip to light in dark mode. Faces stay dark on the white card.
        let outline = scheme == .dark ? Color(red: 0xEC / 255, green: 0xEE / 255, blue: 0xFA / 255) : Self.ink
        if animated {
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                drawing(outline: outline, time: t)
                    .offset(y: CGFloat(sin(t * 3)) * 4)
                    .rotationEffect(.degrees(sin(t * 2) * 3))
            }
        } else {
            drawing(outline: outline, time: 0)
        }
    }

    private func drawing(outline: Color, time t: Double) -> some View {
        let live: CGFloat = t == 0 ? 0 : 1
        let wave = CGFloat(sin(t * 7)) * 6 * live
        // Confetti drifts and twinkles, each piece on its own beat.
        func drift(_ k: Double) -> CGFloat { CGFloat(sin(t * 2.4 + k)) * 3.5 * live }
        return Canvas { context, canvas in
            let s = canvas.width / 120
            // The face is drawn for a card centred at x 62, y 64. The front card of the stack sits a little left and lower.
            let ox: CGFloat = -9.2, oy: CGFloat = 2
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            func fp(_ x: CGFloat, _ y: CGFloat) -> CGPoint { p(x + ox, y + oy) }
            func card(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, fill: Color) {
                let path = Path(roundedRect: CGRect(x: x * s, y: y * s, width: w * s, height: h * s), cornerRadius: 9.6 * s, style: .continuous)
                context.fill(path, with: .color(fill))
                context.stroke(path, with: .color(outline), style: StrokeStyle(lineWidth: 2.6 * s, lineJoin: .round))
            }
            func dot(_ at: CGPoint, _ r: CGFloat, _ color: Color) {
                context.fill(Path(ellipseIn: CGRect(x: at.x - r * s, y: at.y - r * s, width: 2 * r * s, height: 2 * r * s)), with: .color(color))
            }
            func line(_ from: CGPoint, _ to: CGPoint, width: CGFloat, color: Color? = nil) {
                var path = Path(); path.move(to: from); path.addLine(to: to)
                context.stroke(path, with: .color(color ?? outline), style: StrokeStyle(lineWidth: width * s, lineCap: .round))
            }
            func curve(from: CGPoint, to: CGPoint, control: CGPoint) {
                var path = Path(); path.move(to: from); path.addQuadCurve(to: to, control: control)
                context.stroke(path, with: .color(Self.ink), style: StrokeStyle(lineWidth: 2.8 * s, lineCap: .round))
            }
            func blush(_ y: CGFloat) {
                for x: CGFloat in [41, 73] {
                    let at = fp(x, y)
                    context.fill(Path(ellipseIn: CGRect(x: at.x, y: at.y, width: 10 * s, height: 6.4 * s)), with: .color(Self.blush))
                }
            }
            func openMouth(_ y: CGFloat) {
                var mouth = Path()
                mouth.move(to: fp(52, y)); mouth.addQuadCurve(to: fp(72, y), control: fp(62, y + 28)); mouth.closeSubpath()
                context.fill(mouth, with: .color(Self.ink))
                context.stroke(mouth, with: .color(Self.ink), style: StrokeStyle(lineWidth: 2 * s, lineJoin: .round))
            }
            func happyEyes() {
                curve(from: fp(47, 59), to: fp(59, 59), control: fp(53, 52))
                curve(from: fp(65, 59), to: fp(77, 59), control: fp(71, 52))
            }
            /// An arm that starts behind the front card and ends at `hand`.
            func arm(left: Bool, to hand: CGPoint) {
                line(p(left ? 32 : 74, 74), hand, width: 3)
            }
            func zed(_ x: CGFloat, _ y: CGFloat, _ size: CGFloat) {
                var z = Path()
                z.move(to: p(x, y)); z.addLine(to: p(x + size, y)); z.addLine(to: p(x, y + size)); z.addLine(to: p(x + size, y + size))
                context.stroke(z, with: .color(outline), style: StrokeStyle(lineWidth: 2.4 * s, lineCap: .round, lineJoin: .round))
            }

            card(43.2, 19.2, 50.4, 64.8, fill: Color(red: 0xC5 / 255, green: 0xCB / 255, blue: 1))
            card(36, 25.2, 50.4, 67.2, fill: Color(red: 0x73 / 255, green: 0x81 / 255, blue: 1))
            // Arms come out from behind the front card.
            switch mood {
            case .happy:
                arm(left: true, to: p(12, 52)); arm(left: false, to: p(106, 52))
            case .wink:
                arm(left: true, to: p(14, 90)); arm(left: false, to: p(106, 52))
            case .cheer:
                arm(left: true, to: p(12 + wave, 36 - abs(wave) * 0.6)); arm(left: false, to: p(108 - wave, 36 - abs(wave) * 0.6))
            case .sleepy:
                arm(left: true, to: p(14, 94)); arm(left: false, to: p(102, 98))
            case .oops:
                arm(left: true, to: p(16, 88)); arm(left: false, to: p(104, 92))
            case .wow:
                arm(left: true, to: p(8, 44)); arm(left: false, to: p(112, 44))
            }
            card(26.4, 31.2, 52.8, 69.6, fill: .white)

            switch mood {
            case .happy:
                happyEyes(); blush(66); openMouth(68)
            case .wink:
                dot(fp(53, 59), 4, Self.ink)
                curve(from: fp(66, 60), to: fp(78, 60), control: fp(72, 53))
                blush(67); curve(from: fp(52, 70), to: fp(74, 70), control: fp(65, 80))
            case .cheer:
                happyEyes(); blush(66); openMouth(68)
            case .sleepy:
                curve(from: fp(47, 60), to: fp(59, 60), control: fp(53, 66))
                curve(from: fp(65, 60), to: fp(77, 60), control: fp(71, 66))
                blush(68)
                context.fill(Path(ellipseIn: CGRect(x: fp(59.5, 71).x, y: fp(59.5, 71).y, width: 5 * s, height: 6 * s)), with: .color(Self.ink))
            case .oops:
                dot(fp(53, 60), 3.6, Self.ink); dot(fp(71, 60), 3.6, Self.ink)
                line(fp(47, 54), fp(57, 51), width: 2.4, color: Self.ink)
                line(fp(67, 51), fp(77, 54), width: 2.4, color: Self.ink)
                curve(from: fp(54, 74), to: fp(70, 74), control: fp(62, 66))
            case .wow:
                for x: CGFloat in [53, 71] {
                    let at = fp(x, 59)
                    context.fill(Path(ellipseIn: CGRect(x: at.x - 5.2 * s, y: at.y - 5.2 * s, width: 10.4 * s, height: 10.4 * s)), with: .color(.white))
                    context.stroke(Path(ellipseIn: CGRect(x: at.x - 5.2 * s, y: at.y - 5.2 * s, width: 10.4 * s, height: 10.4 * s)), with: .color(Self.ink), style: StrokeStyle(lineWidth: 2 * s))
                    dot(at, 2.4, Self.ink)
                }
                blush(68)
                let mouth = fp(62, 73)
                context.fill(Path(ellipseIn: CGRect(x: mouth.x - 3.6 * s, y: mouth.y - 4.6 * s, width: 7.2 * s, height: 9.2 * s)), with: .color(Self.ink))
            }

            switch mood {
            case .sleepy:
                zed(98, 28 + drift(0), 8); zed(108, 14 + drift(2), 6)
            case .oops:
                var drop = Path()
                drop.move(to: p(102, 24 + drift(0))); drop.addQuadCurve(to: p(102, 41 + drift(0)), control: p(92, 40 + drift(0)))
                drop.addQuadCurve(to: p(102, 24 + drift(0)), control: p(112, 40 + drift(0)))
                context.fill(drop, with: .color(Color.hex(0x7FC8FF)))
                context.stroke(drop, with: .color(Self.ink), style: StrokeStyle(lineWidth: 1.6 * s, lineJoin: .round))
            default:
                dot(p(12, 24 + drift(0)), 4, Self.gold); dot(p(106, 16 + drift(1.5)), 3.6, Color.hex(0xE0424A))
                dot(p(112, 62 + drift(3)), 3.2, Color.hex(0x2FC68C)); dot(p(8, 64 + drift(4.5)), 3.2, Color.hex(0x3B4CF5))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Card mascot")
    }
}
