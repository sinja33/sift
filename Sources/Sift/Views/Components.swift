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

/// Five white bars that bounce like a level meter. Shown on the cover while a song loads.
struct EqualizerView: View {
    var height: CGFloat = 52

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<5, id: \.self) { i in
                    // Each bar runs on its own phase and speed so they never move in step.
                    let wave = (sin(t * (5.2 + Double(i) * 0.7) + Double(i) * 1.9) + 1) / 2
                    Capsule()
                        .fill(.white)
                        .frame(width: 9, height: height * (0.22 + 0.78 * wave))
                }
            }
            .frame(height: height, alignment: .bottom)
        }
        .accessibilityLabel("Loading")
    }
}
