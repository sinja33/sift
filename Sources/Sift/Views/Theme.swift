import AppKit
import SwiftUI

/// Colours and fonts from the Sift design guide. Each colour has a light and a dark value.
enum Theme {
    static let brand = Color.dynamic(light: 0x3B4CF5, dark: 0x7381FF)
    static let keep = Color.dynamic(light: 0x12A06B, dark: 0x2FC68C)
    static let delete = Color.dynamic(light: 0xE0424A, dark: 0xFF6A6F)
    static let chance = Color.dynamic(light: 0xE39E12, dark: 0xF6B93B)
    static let keepSoft = Color.dynamic(light: 0xDDF4EA, dark: 0x133327)
    static let deleteSoft = Color.dynamic(light: 0xFCE4E5, dark: 0x3A1C21)
    static let chanceSoft = Color.dynamic(light: 0xFBF0D6, dark: 0x3A2E12)
    static let paper = Color.dynamic(light: 0xF5F6FB, dark: 0x0D0E19)
    static let surface = Color.dynamic(light: 0xFFFFFF, dark: 0x171928)
    static let surface2 = Color.dynamic(light: 0xECEEF6, dark: 0x20233A)
    static let ink = Color.dynamic(light: 0x15172A, dark: 0xECEEFA)
    static let muted = Color.dynamic(light: 0x5B6080, dark: 0x9CA1C4)
    static let line = Color.dynamic(light: 0xDCDFEB, dark: 0x2C3050)
    static let onAction = Color.dynamic(light: 0xFFFFFF, dark: 0x0D0E19)

    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy) }
    static func mono(_ size: CGFloat) -> Font { .system(size: size, weight: .medium, design: .monospaced) }
}

extension Color {
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }

    static func hex(_ value: UInt32) -> Color { Color(nsColor: NSColor(hex: value)) }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1)
    }
}

/// Shows the pointing-hand cursor over anything you can click, unless it is disabled.
private struct PointerCursor: ViewModifier {
    @Environment(\.isEnabled) private var enabled
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                guard inside != hovering else { return }
                hovering = inside
                if inside && enabled { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            .onChange(of: enabled) { _, now in
                guard hovering else { return }
                if now { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            .onDisappear {
                if hovering && enabled { NSCursor.pop() }
                hovering = false
            }
    }
}

extension View {
    func pointerCursor() -> some View { modifier(PointerCursor()) }
}

struct CapsuleButtonStyle: ButtonStyle {
    var fill: Color
    var text: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(fill, in: Capsule())
            .foregroundStyle(text)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.smooth(duration: 0.15), value: configuration.isPressed)
            .contentShape(Capsule())
            .pointerCursor()
    }
}

extension ButtonStyle where Self == CapsuleButtonStyle {
    static var primary: CapsuleButtonStyle { CapsuleButtonStyle(fill: Theme.brand, text: Theme.onAction) }
    static var secondary: CapsuleButtonStyle { CapsuleButtonStyle(fill: Theme.surface2, text: Theme.ink) }
    static var danger: CapsuleButtonStyle { CapsuleButtonStyle(fill: Theme.delete, text: Theme.onAction) }
}

extension View {
    /// The bordered white box used for panels and lists.
    func panel(padding: CGFloat = 18, radius: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.line))
    }
}

/// Fades and lifts a view into place when it first appears, after an optional delay.
private struct Reveal: ViewModifier {
    var delay: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .onAppear { withAnimation(.spring(duration: 0.55, bounce: 0.12).delay(delay)) { shown = true } }
    }
}

/// A soft band of light that sweeps across a placeholder while content loads.
private struct Shimmer: ViewModifier {
    var active: Bool
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content.overlay {
            if active {
                GeometryReader { geo in
                    LinearGradient(colors: [.clear, Color.white.opacity(0.22), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 0.5)
                        .offset(x: -geo.size.width * 0.5 + phase * geo.size.width * 1.5)
                }
                .allowsHitTesting(false)
                .onAppear { withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { phase = 1 } }
            }
        }
        .clipped()
    }
}

extension View {
    func reveal(delay: Double = 0) -> some View { modifier(Reveal(delay: delay)) }
    func shimmer(_ active: Bool = true) -> some View { modifier(Shimmer(active: active)) }
}

/// An empty panel shown where a panel will appear once the library has loaded.
struct SkeletonPanel: View {
    var height: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule().fill(Theme.surface2).frame(width: 150, height: 14)
            Capsule().fill(Theme.surface2).frame(height: 10)
            Capsule().fill(Theme.surface2).frame(width: 220, height: 10)
            Spacer(minLength: 0)
            Capsule().fill(Theme.surface2).frame(width: 130, height: 36)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: height, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shimmer()
    }
}
