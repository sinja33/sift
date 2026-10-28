import SwiftUI

/// The fanned stack of cards from the design guide: amber and red cards behind a record sleeve.
struct LogoMark: View {
    var size: CGFloat = 96

    var body: some View {
        let s = size / 120
        let vinyl = Color.hex(0x15172A)
        ZStack {
            RoundedRectangle(cornerRadius: 28 * s, style: .continuous)
                .fill(LinearGradient(colors: [.hex(0x5465FF), .hex(0x2433C7)], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 9 * s, style: .continuous)
                .fill(Color.hex(0xE39E12))
                .frame(width: 50 * s, height: 66 * s)
                .rotationEffect(.degrees(-16))
            RoundedRectangle(cornerRadius: 9 * s, style: .continuous)
                .fill(Color.hex(0xE0424A))
                .frame(width: 50 * s, height: 66 * s)
                .rotationEffect(.degrees(14))
            ZStack {
                RoundedRectangle(cornerRadius: 10 * s, style: .continuous)
                    .fill(.white)
                    .frame(width: 54 * s, height: 72 * s)
                Circle().fill(vinyl).frame(width: 34 * s, height: 34 * s).offset(y: -8 * s)
                Circle().fill(Color.hex(0x3B4CF5)).frame(width: 12 * s, height: 12 * s).offset(y: -8 * s)
                Capsule().fill(vinyl.opacity(0.85)).frame(width: 36 * s, height: 5 * s).offset(y: 19.5 * s)
                Capsule().fill(vinyl.opacity(0.35)).frame(width: 22 * s, height: 4 * s).offset(x: -7 * s, y: 27 * s)
            }
            .offset(y: -2 * s)
        }
        .frame(width: size, height: size)
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
        .buttonStyle(.plain)
        .help(decision.label)
    }
}

struct HealthRing: View {
    let value: Double

    var body: some View {
        ZStack {
            Circle().stroke(Theme.surface2, lineWidth: 12)
            Circle()
                .trim(from: 0, to: max(0.001, value))
                .stroke(Theme.brand, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((value * 100).rounded()))%").font(Theme.display(26))
        }
        .frame(width: 120, height: 120)
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
                image = nil
                guard loads else { return }
                image = await model.artwork(for: song)
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
