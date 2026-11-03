import SwiftUI

/// The Sift mark. See LogoDrawing for how it is drawn.
struct LogoMark: View {
    var size: CGFloat = 96
    /// Draw only the cards, with no tile behind them.
    var cardsOnly = false

    var body: some View {
        Canvas { context, canvasSize in
            if cardsOnly {
                // The stack spans about x 17...79, y 11...85 on the 96 grid, centred; grow it to fill the frame.
                let side = canvasSize.width * 1.2
                let rect = CGRect(x: (canvasSize.width - side) / 2, y: (canvasSize.height - side) / 2, width: side, height: side)
                LogoDrawing.draw(in: &context, rect: rect, tile: false)
            } else {
                LogoDrawing.draw(in: &context, rect: CGRect(origin: .zero, size: canvasSize))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Sift")
    }
}

struct Pill: View {
    let text: String
    let tint: Color
    let soft: Color

    init(_ text: String, tint: Color = Theme.muted, soft: Color = Theme.surface2) {
        self.text = text
        self.tint = tint
        self.soft = soft
    }

    init(_ text: String, decision: Decision) {
        self.init(text, tint: decision.tint, soft: decision.soft)
    }

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(soft, in: Capsule())
            .foregroundStyle(tint)
            .lineLimit(1)
            .contentTransition(.numericText())
    }
}

struct StatView: View {
    let value: String
    let label: String
    var size: CGFloat = 15

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(Theme.mono(size)).monospacedDigit()
            Text(label.uppercased()).font(.system(size: 10, weight: .medium)).tracking(0.6).foregroundStyle(Theme.muted)
        }
    }
}

struct ActionButton: View {
    let decision: Decision
    var size: CGFloat = 56
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: decision.symbol)
                .font(.system(size: size * 0.4, weight: .bold))
                .frame(width: size, height: size)
                .foregroundStyle(decision.tint)
                .background(Circle().fill(Theme.surface))
                .overlay(Circle().stroke(decision.tint, lineWidth: 2))
                .contentShape(Circle())
        }
        .buttonStyle(ActionPress())
        .pointerCursor()
        .help(decision.label)
    }
}

/// Grows slightly under the cursor and shrinks when pressed.
private struct ActionPress: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : hovering ? 1.08 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.3), value: configuration.isPressed)
            .animation(.spring(duration: 0.25, bounce: 0.3), value: hovering)
            .onHover { hovering = $0 }
    }
}

/// Share of the library played recently. Spins while the library is loading, then fills to the value.
struct HealthRing: View {
    let value: Double
    var loading = false

    @State private var shown: Double = 0
    @State private var spinning = false

    private let line: CGFloat = 14
    private var target: Double { loading ? 0 : min(1, max(0, value)) }

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.surface)
                .overlay(Circle().stroke(Theme.line))
            Circle().stroke(Theme.surface2, lineWidth: line).padding(line / 2 + 6)

            if loading {
                arc(to: 0.26)
                    .rotationEffect(.degrees(spinning ? 360 : 0))
                    .animation(.linear(duration: 1.1).repeatForever(autoreverses: false), value: spinning)
            } else {
                arc(to: max(0.001, shown))
                // A small dot at the end of the arc.
                Circle()
                    .fill(.white)
                    .frame(width: 6, height: 6)
                    .padding(.top, 6 + line / 2 - 3)
                    .frame(width: 156, height: 156, alignment: .top)
                    .rotationEffect(.degrees(360 * shown))
                    .opacity(shown > 0.02 ? 1 : 0)
            }

            VStack(spacing: 3) {
                if loading {
                    Text("Reading").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
                    Text("library…").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        CountText(value: shown * 100).font(Theme.display(40))
                        Text("%").font(Theme.display(20)).foregroundStyle(Theme.muted)
                    }
                    Text("PLAYED").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(Theme.muted)
                }
            }
        }
        .frame(width: 156, height: 156)
        .onChange(of: target, initial: true) {
            withAnimation(.easeOut(duration: 1.2)) { shown = target }
        }
        .onChange(of: loading, initial: true) { spinning = loading }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(loading ? "Reading library" : "\(Int((value * 100).rounded())) percent of your library played recently")
    }

    /// The coloured arc, starting at the top.
    private func arc(to end: Double) -> some View {
        Circle()
            .trim(from: 0, to: end)
            .stroke(
                AngularGradient(
                    colors: [Color.hex(0x9AA6FF), Theme.brand, Color.hex(0x5A3FE0)],
                    center: .center, startAngle: .degrees(0), endAngle: .degrees(360 * max(end, 0.05))),
                style: StrokeStyle(lineWidth: line, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .padding(line / 2 + 6)
    }
}

/// A number that counts up smoothly when its value is animated.
private struct CountText: View, Animatable {
    var value: Double
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View { Text("\(Int(value.rounded()))") }
}

/// A rounded segmented control.
struct PillPicker<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String
    @Namespace private var slider

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let on = option == selection
                Button { withAnimation(.smooth(duration: 0.25)) { selection = option } } label: {
                    Text(label(option))
                        .font(.system(size: 13, weight: on ? .semibold : .regular))
                        .foregroundStyle(on ? Theme.ink : Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background {
                            if on {
                                Capsule().fill(Theme.surface).shadow(color: .black.opacity(0.10), radius: 1.5, y: 1)
                                    .matchedGeometryEffect(id: "selected", in: slider)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }
        }
        .padding(4)
        .background(Theme.surface2, in: Capsule())
    }
}

struct KeyCap: View {
    let key: String

    var body: some View {
        Text(key)
            .font(Theme.mono(12))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.line))
    }
}

struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.ink, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .foregroundStyle(Theme.paper)
            .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
    }
}

/// Album art from Music, with a gradient while it loads or when a song has none.
struct ArtworkView: View {
    let song: Song
    var loads = true
    var cornerRadius: CGFloat = 12

    @Environment(AppModel.self) private var model
    @State private var image: NSImage?

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(nsImage: image).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: placeholderColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .task(id: song.id) {
                image = model.cachedArtwork(for: song)
                guard loads, image == nil else { return }
                image = await model.artwork(for: song)
            }
            // Fetching a cover can queue behind the song starting; try again once that is done.
            .onChange(of: model.clipLoading) { _, loading in
                guard loads, !loading, image == nil else { return }
                Task { image = await model.artwork(for: song) }
            }
    }

    private var placeholderColors: [Color] {
        let seed = song.id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFFFF }
        let hue = Double(seed % 360) / 360
        return [
            Color(hue: hue, saturation: 0.6, brightness: 0.95),
            Color(hue: (hue + 0.18).truncatingRemainder(dividingBy: 1), saturation: 0.8, brightness: 0.45)
        ]
    }
}

/// A song as a compact row, used on the review and Second Chance screens.
struct SongRow<Trailing: View>: View {
    let song: Song
    let detail: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(song: song, loads: false, cornerRadius: 6).frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(song.title).fontWeight(.semibold).lineLimit(1)
                Text(detail).font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.vertical, 8)
    }
}

/// A ring with a bright arc chasing around it. Looks like waiting, not like music playing.
struct LoadingRing: View {
    var size: CGFloat = 56

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                Circle().stroke(.white.opacity(0.22), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: 0.28)
                    .stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(t * 320))
            }
            .frame(width: size, height: size)
        }
        .accessibilityLabel("Loading")
    }
}

/// The artist's photo in a circle, with their initial on a colored tile until it loads or when none is found.
struct ArtistAvatar: View {
    let artist: String
    var size: CGFloat = 72

    @Environment(AppModel.self) private var model
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                gradient
                Text(String(artist.prefix(1)).uppercased()).font(Theme.display(size * 0.42)).foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Theme.line))
        .task(id: artist) {
            image = nil
            image = await model.artistImage(for: artist)
        }
    }

    private var gradient: LinearGradient {
        let seed = artist.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFFFF }
        let hue = Double(seed % 360) / 360
        return LinearGradient(colors: [
            Color(hue: hue, saturation: 0.6, brightness: 0.95),
            Color(hue: (hue + 0.18).truncatingRemainder(dividingBy: 1), saturation: 0.8, brightness: 0.45)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// A mascot, a title and a line of explanation, for screens with nothing to show or something that went wrong.
struct EmptyState<Actions: View>: View {
    let mood: Mascot.Mood
    let title: String
    let message: String
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 12) {
            Mascot(mood: mood, size: 120, animated: true)
            Text(title).font(Theme.display(24)).multilineTextAlignment(.center)
            Text(message)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) { actions }.padding(.top, 6)
        }
        .frame(maxWidth: 420)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
    }
}

/// The indigo circle behind all three Home icons.
private func drawIconBackdrop(_ context: inout GraphicsContext, _ canvas: CGSize) {
    context.fill(Path(ellipseIn: CGRect(origin: .zero, size: canvas)), with: .linearGradient(
        Gradient(colors: [Color.hex(0x6F7DFF), Color.hex(0x3B4CF5)]), startPoint: .zero, endPoint: CGPoint(x: canvas.width, y: canvas.height)))
}

/// The Second Chance mark: the logo's music note inside a "try again" arrow, on a gold circle.
struct SecondChanceIcon: View {
    var size: CGFloat = 72

    var body: some View {
        Canvas { context, canvas in
            let s = canvas.width / 72
            let c = CGPoint(x: 36 * s, y: 36 * s)
            let r = 23 * s
            drawIconBackdrop(&context, canvas)
            // An open ring that runs counterclockwise from the upper left round to the upper right, with an arrowhead at the end.
            let start = Angle.degrees(-40), end = Angle.degrees(230)
            var ring = Path()
            ring.addArc(center: c, radius: r, startAngle: end, endAngle: start, clockwise: true)
            context.stroke(ring, with: .color(.white), style: StrokeStyle(lineWidth: 4.2 * s, lineCap: .round))
            let a = CGFloat(start.radians)
            let tip = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
            let dir = CGPoint(x: sin(a), y: -cos(a))
            let side = CGPoint(x: -dir.y, y: dir.x)
            var head = Path()
            head.move(to: CGPoint(x: tip.x - 9 * s * dir.x + 6.5 * s * side.x, y: tip.y - 9 * s * dir.y + 6.5 * s * side.y))
            head.addLine(to: tip)
            head.addLine(to: CGPoint(x: tip.x - 9 * s * dir.x - 6.5 * s * side.x, y: tip.y - 9 * s * dir.y - 6.5 * s * side.y))
            context.stroke(head, with: .color(.white), style: StrokeStyle(lineWidth: 4.2 * s, lineCap: .round, lineJoin: .round))
            // The note, centred on the circle.
            let box = LogoDrawing.note.boundingRect
            let scale = 0.8 * s
            let toCenter = CGAffineTransform(translationX: c.x, y: c.y).scaledBy(x: scale, y: scale)
                .translatedBy(x: -box.midX, y: -box.midY)
            context.fill(LogoDrawing.note.applying(toCenter), with: .color(.white))
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(Theme.line))
        .accessibilityLabel("Second Chance")
    }
}

/// A card being swiped, with the swipe arc above it, on an indigo circle.
struct SwipeIcon: View {
    var size: CGFloat = 72

    var body: some View {
        Canvas { context, canvas in
            let s = canvas.width / 72
            drawIconBackdrop(&context, canvas)
            func card(at center: CGPoint, degrees: Double, fill: Color) {
                let rect = CGRect(x: -11 * s, y: -15 * s, width: 22 * s, height: 30 * s)
                let t = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: degrees * .pi / 180)
                context.fill(Path(roundedRect: rect, cornerRadius: 5 * s, style: .continuous).applying(t), with: .color(fill))
            }
            card(at: CGPoint(x: 27 * s, y: 43 * s), degrees: -14, fill: .white.opacity(0.45))
            card(at: CGPoint(x: 42 * s, y: 43 * s), degrees: 12, fill: .white)
            // The swipe: an arc over the cards, ending in an arrowhead on the right.
            var arc = Path()
            arc.move(to: CGPoint(x: 18 * s, y: 22 * s))
            arc.addQuadCurve(to: CGPoint(x: 52 * s, y: 20 * s), control: CGPoint(x: 35 * s, y: 8 * s))
            context.stroke(arc, with: .color(.white), style: StrokeStyle(lineWidth: 3.6 * s, lineCap: .round))
            var head = Path()
            head.move(to: CGPoint(x: 46 * s, y: 13 * s)); head.addLine(to: CGPoint(x: 53 * s, y: 20.5 * s)); head.addLine(to: CGPoint(x: 44 * s, y: 25 * s))
            context.stroke(head, with: .color(.white), style: StrokeStyle(lineWidth: 3.6 * s, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(Theme.line))
        .accessibilityLabel("Swipe session")
    }
}

/// A person with a small music note, for the artist spotlight.
struct ArtistIcon: View {
    var size: CGFloat = 72

    var body: some View {
        Canvas { context, canvas in
            let s = canvas.width / 72
            drawIconBackdrop(&context, canvas)
            context.fill(Path(ellipseIn: CGRect(x: 27 * s, y: 15 * s, width: 18 * s, height: 18 * s)), with: .color(.white))
            // The shoulders run off the bottom of the circle.
            var shoulders = context
            shoulders.clip(to: Path(ellipseIn: CGRect(origin: .zero, size: canvas)))
            var body = Path()
            body.move(to: CGPoint(x: 15 * s, y: 74 * s))
            body.addLine(to: CGPoint(x: 15 * s, y: 56 * s))
            body.addCurve(to: CGPoint(x: 36 * s, y: 38 * s), control1: CGPoint(x: 15 * s, y: 44 * s), control2: CGPoint(x: 23 * s, y: 38 * s))
            body.addCurve(to: CGPoint(x: 57 * s, y: 56 * s), control1: CGPoint(x: 49 * s, y: 38 * s), control2: CGPoint(x: 57 * s, y: 44 * s))
            body.addLine(to: CGPoint(x: 57 * s, y: 74 * s))
            body.closeSubpath()
            shoulders.fill(body, with: .color(.white))
            let note = CGAffineTransform(translationX: 54 * s, y: 17 * s).scaledBy(x: 0.6 * s, y: 0.6 * s).translatedBy(x: -12, y: -12)
            context.fill(LogoDrawing.note.applying(note), with: .color(.white))
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(Theme.line))
        .accessibilityLabel("Artist")
    }
}

/// A bin, for songs waiting to be deleted.
struct DeleteIcon: View {
    var size: CGFloat = 72

    var body: some View {
        Canvas { context, canvas in
            let s = canvas.width / 72
            drawIconBackdrop(&context, canvas)
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            context.fill(Path(roundedRect: CGRect(x: 31 * s, y: 17 * s, width: 10 * s, height: 6 * s), cornerRadius: 2 * s), with: .color(.white))
            context.fill(Path(roundedRect: CGRect(x: 20 * s, y: 22 * s, width: 32 * s, height: 5 * s), cornerRadius: 2.5 * s), with: .color(.white))
            var bin = Path()
            bin.move(to: pt(24, 30)); bin.addLine(to: pt(48, 30)); bin.addLine(to: pt(46.2, 53))
            bin.addQuadCurve(to: pt(43.4, 56), control: pt(46, 56)); bin.addLine(to: pt(28.6, 56))
            bin.addQuadCurve(to: pt(25.8, 53), control: pt(26, 56)); bin.closeSubpath()
            context.fill(bin, with: .color(.white))
            for x: CGFloat in [31.5, 36, 40.5] {
                var slit = Path(); slit.move(to: pt(x, 36)); slit.addLine(to: pt(x, 50))
                context.stroke(slit, with: .color(Color.hex(0x4F5EFA)), style: StrokeStyle(lineWidth: 2.4 * s, lineCap: .round))
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(Theme.line))
        .accessibilityLabel("Ready to delete")
    }
}
