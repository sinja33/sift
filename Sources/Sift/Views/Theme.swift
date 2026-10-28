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
            .contentShape(Capsule())
    }
}

extension ButtonStyle where Self == CapsuleButtonStyle {
    static var primary: CapsuleButtonStyle { CapsuleButtonStyle(fill: Theme.brand, text: Theme.onAction) }
    static var secondary: CapsuleButtonStyle { CapsuleButtonStyle(fill: Theme.surface2, text: Theme.ink) }
    static var danger: CapsuleButtonStyle { CapsuleButtonStyle(fill: Theme.delete, text: Theme.onAction) }
}

extension View {
    /// The bordered white box used for panels and lists.
    func panel(padding: CGFloat = 18) -> some View {
        self
            .padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line))
    }
}
