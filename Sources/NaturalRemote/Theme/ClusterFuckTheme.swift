import SwiftUI

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Semantic palette from `design-system/clusterfuck/MASTER.md` with dark HUD
/// overrides from `pages/watchos.md` / `pages/macos.md`. Hex lives here only.
public enum ClusterFuckPalette: Sendable {
    /// ΔS · configurational entropy · σ_irr ring
    public static let primary: UInt32 = 0x8B5CF6
    /// ΔS_vib · environment / AirPods
    public static let secondary: UInt32 = 0x00A2FF
    /// ΔH · closure / calm CTA
    public static let accent: UInt32 = 0x45E0A8
    /// Light paper (family, not clinical sky)
    public static let lightBackground: UInt32 = 0xF8FAFC
    /// NATURaL / Shannon ink
    public static let darkBackground: UInt32 = 0x08091A
    public static let lightSurface: UInt32 = 0xFFFFFF
    public static let darkSurface: UInt32 = 0x111226
    public static let lightInk: UInt32 = 0x08091A
    public static let darkInk: UInt32 = 0xE4E3F5
    public static let lightMute: UInt32 = 0x475569
    public static let darkMute: UInt32 = 0x8D8CB0
    public static let lightBorder: UInt32 = 0xCBD5E1
    public static let darkBorder: UInt32 = 0x334155
    /// T · fail
    public static let destructive: UInt32 = 0xF5232B
    /// Receptor · elevated σ_irr
    public static let warning: UInt32 = 0xFF2F92
}

/// Density 8 dashboard grid from MASTER.md.
public enum ClusterFuckSpacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
}

public enum ClusterFuckRadius {
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
}

public enum ClusterFuckIconSize {
    public static let sm: CGFloat = 16
    public static let md: CGFloat = 20
    public static let hit: CGFloat = 44
}

/// Subtle motion (dial 3). Pair with `accessibilityReduceMotion`.
public enum ClusterFuckMotion {
    public static let short: Double = 0.18
    public static let standard: Double = 0.22

    public static func animation(reduceMotion: Bool, duration: Double = standard) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: duration)
    }
}

/// Outline SF Symbols — one family, never emoji.
public enum ClusterFuckSymbol: String, Sendable {
    case sigma = "waveform.path.ecg"
    case music = "speaker.wave.2"
    case dose = "pills"
    case environment = "airpods.pro"
    case minimize = "arrow.down.circle"
    case session = "dot.radiowaves.left.and.right"

    public var systemName: String { rawValue }
}

public enum ClusterFuckType {
    public static var display: Font { .system(.title2, design: .default).weight(.semibold) }
    public static var headline: Font { .headline }
    public static var body: Font { .body }
    public static var caption: Font { .caption }
    public static var mono: Font { .body.monospacedDigit().weight(.medium) }
}

/// Pressed scale stays inside the hit box. 180ms, Reduce Motion off.
public struct ClusterFuckPressStyle: ButtonStyle {
    public var pressedScale: CGFloat = 0.97

    public init(pressedScale: CGFloat = 0.97) {
        self.pressedScale = pressedScale
    }

    public func makeBody(configuration: Configuration) -> some View {
        ClusterFuckPressStyleBody(configuration: configuration, pressedScale: pressedScale)
    }
}

private struct ClusterFuckPressStyleBody: View {
    let configuration: ButtonStyleConfiguration
    var pressedScale: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(
                ClusterFuckMotion.animation(reduceMotion: reduceMotion, duration: ClusterFuckMotion.short),
                value: configuration.isPressed
            )
    }
}

public struct ClusterFuckLoadingRow: View {
    public init() {}

    public var body: some View {
        HStack(spacing: ClusterFuckSpacing.sm) {
            ProgressView()
                .accessibilityHidden(true)
            Text("Working…")
                .font(ClusterFuckType.caption)
                .foregroundStyle(Color.clusterFuckMute)
        }
        .frame(maxWidth: .infinity, minHeight: ClusterFuckIconSize.hit, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Working")
    }
}

public struct ClusterFuckRGBA: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(hex: UInt32, alpha: Double = 1) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
        self.alpha = alpha
    }

    public var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

public enum ClusterFuckAdaptiveColor {
    public static func make(light: UInt32, dark: UInt32, alpha: Double = 1) -> Color {
        #if os(macOS)
        return Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let darkMode = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let rgba = ClusterFuckRGBA(hex: darkMode ? dark : light, alpha: alpha)
            return NSColor(srgbRed: rgba.red, green: rgba.green, blue: rgba.blue, alpha: rgba.alpha)
        }))
        #elseif canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            let rgba = ClusterFuckRGBA(
                hex: traits.userInterfaceStyle == .dark ? dark : light,
                alpha: alpha
            )
            return UIColor(red: rgba.red, green: rgba.green, blue: rgba.blue, alpha: rgba.alpha)
        })
        #else
        return ClusterFuckRGBA(hex: dark, alpha: alpha).color
        #endif
    }
}

public extension Color {
    static var clusterFuckBackground: Color {
        ClusterFuckAdaptiveColor.make(light: ClusterFuckPalette.lightBackground, dark: ClusterFuckPalette.darkBackground)
    }
    static var clusterFuckSurface: Color {
        ClusterFuckAdaptiveColor.make(light: ClusterFuckPalette.lightSurface, dark: ClusterFuckPalette.darkSurface)
    }
    static var clusterFuckInk: Color {
        ClusterFuckAdaptiveColor.make(light: ClusterFuckPalette.lightInk, dark: ClusterFuckPalette.darkInk)
    }
    static var clusterFuckMute: Color {
        ClusterFuckAdaptiveColor.make(light: ClusterFuckPalette.lightMute, dark: ClusterFuckPalette.darkMute)
    }
    static var clusterFuckBorder: Color {
        ClusterFuckAdaptiveColor.make(light: ClusterFuckPalette.lightBorder, dark: ClusterFuckPalette.darkBorder)
    }
    static var clusterFuckPrimary: Color { ClusterFuckRGBA(hex: ClusterFuckPalette.primary).color }
    static var clusterFuckOnAccent: Color { ClusterFuckRGBA(hex: ClusterFuckPalette.darkBackground).color }
    static var clusterFuckAccent: Color { ClusterFuckRGBA(hex: ClusterFuckPalette.accent).color }
    static var clusterFuckWarning: Color { ClusterFuckRGBA(hex: ClusterFuckPalette.warning).color }
    static var clusterFuckDestructive: Color { ClusterFuckRGBA(hex: ClusterFuckPalette.destructive).color }
}

public enum ClusterFuckSigmaBand: String, Sendable {
    case unknown
    case closed
    case settling
    case elevated

    public static func classify(_ sigmaIrr: Double) -> ClusterFuckSigmaBand {
        if !sigmaIrr.isFinite { return .unknown }
        if sigmaIrr < 0.03 { return .closed }
        if sigmaIrr <= 0.15 { return .settling }
        return .elevated
    }

    public var color: Color {
        switch self {
        case .unknown: return .clusterFuckMute
        case .closed: return .clusterFuckAccent
        case .settling: return .clusterFuckPrimary
        case .elevated: return .clusterFuckWarning
        }
    }
}
