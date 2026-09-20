import SwiftUI

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Semantic palette from FlexAID∆S **palette v2** (`tokens.css`, Le Bonhomme
/// Pharma), with the dark HUD surfaces from `pages/watchos.md` / `pages/macos.md`.
/// Hex lives here only.
///
/// Each key colour is bound to a thermodynamic quantity and the binding is the
/// system — a key colour is never reassigned. Retired v1 names (teal, gold,
/// terra, cyan, coral, green) must not be reintroduced.
///
/// Light-mode `*Light` variants keep the key colour's **hue and chroma exactly**
/// and move only lightness, because hue and chroma carry the identity while
/// lightness is free. They exist because the v2 key colours are tuned for the
/// indigo ink and drop below WCAG AA on a light ground (mint is 1.68:1 on white).
/// Ratios in the comments are measured against the worst-case light ground
/// `#F4F6FB`; on the white card they are ~0.4 higher.
public enum ClusterFuckPalette: Sendable {
    // ───────── KEY COLOURS (dark ground) ─────────
    /// ΔS · configurational entropy · σ_irr ring
    public static let primary: UInt32 = 0x8B5CF6
    /// ΔS_vib · vibrational · environment / AirPods
    public static let secondary: UInt32 = 0x00A2FF
    /// ΔH · enthalpy · closure / calm CTA
    public static let accent: UInt32 = 0x45E0A8
    /// ΔG · free energy · stats
    public static let tangerine: UInt32 = 0xFF9300
    /// Baseline · apo · reference line
    public static let magnesium: UInt32 = 0xDCDCE4
    /// T · temperature · fail
    public static let destructive: UInt32 = 0xF5232B
    /// Receptor · pocket · elevated σ_irr
    public static let warning: UInt32 = 0xFF2F92

    // ───────── KEY COLOURS (light ground) ─────────
    // Same hue and saturation, lower lightness. All ≥4.5:1 on `#F4F6FB`.
    /// ΔS on light · hue 258.3°, 4.64:1
    public static let primaryLight: UInt32 = 0x7E4AF5
    /// ΔS_vib on light · hue 201.9°, 4.64:1
    public static let secondaryLight: UInt32 = 0x0074B7
    /// ΔH on light · hue 158.3°, 4.61:1
    public static let accentLight: UInt32 = 0x157F59
    /// ΔG on light · hue 34.6°, 4.61:1
    public static let tangerineLight: UInt32 = 0xA45F00
    /// Baseline on light · hue 240.0°, 4.66:1
    public static let magnesiumLight: UInt32 = 0x6C6C8D
    /// Receptor on light · hue 331.4°, 4.61:1
    public static let warningLight: UInt32 = 0xDB0068

    /// `--state-fail-text`: firetruck lifted for small failure labels.
    /// Canon holds firetruck itself to 12px and up.
    public static let failTextDark: UInt32 = 0xFF6B6B   // 6.70:1 on dark surface
    public static let failTextLight: UInt32 = 0xBE123C  // 5.81:1 on `#F4F6FB`

    // ───────── SURFACES ─────────
    /// `--bg` light
    public static let lightBackground: UInt32 = 0xF4F6FB
    /// `--bg-card` light
    public static let lightSurface: UInt32 = 0xFFFFFF
    /// `--bg` dark · NATURaL / Shannon indigo ink, never navy
    public static let darkBackground: UInt32 = 0x08091A
    /// `--bg-card` dark · the ink washed, not a solid mid-tone
    public static let darkSurface: UInt32 = 0x111226
    /// `--fg` light
    public static let lightInk: UInt32 = 0x1E293B
    /// `--fg` dark
    public static let darkInk: UInt32 = 0xE4E3F5
    /// `--fg-muted` light · 5.50:1 on `#F4F6FB`
    public static let lightMute: UInt32 = 0x5A6478
    /// `--fg-muted` dark · 6.12:1 on the ink
    public static let darkMute: UInt32 = 0x8D8CB0

    /// Borders are violet alpha washes over the ground, per canon — never a
    /// neutral slate rule. Alpha differs by theme because the same opacity
    /// reads weaker over a light ground.
    public static let border: UInt32 = 0x8B5CF6
    /// `--violet-25`
    public static let lightBorderAlpha: Double = 0.25
    /// `--violet-35`
    public static let darkBorderAlpha: Double = 0.35
}

/// Density 8 dashboard grid from MASTER.md.
///
/// The raw ladder is 4-based. The semantic tier below is what views should
/// reach for: using `sm` for both "gap inside a control" and "gap between
/// sections" is what makes a dense HUD read as undifferentiated mush.
public enum ClusterFuckSpacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24

    // ───────── Semantic tiers ─────────
    /// Between elements inside one group (label and its value).
    public static let withinGroup: CGFloat = xs
    /// Between sibling controls in a row.
    public static let betweenControls: CGFloat = sm
    /// Between distinct sections of a page.
    public static let betweenSections: CGFloat = lg
    /// Page edge inset, compact (watch / phone).
    public static let pageCompact: CGFloat = md
    /// Page edge inset, regular (iPad / Mac).
    public static let pageRegular: CGFloat = xl
}

public enum ClusterFuckRadius {
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
}

public enum ClusterFuckIconSize {
    /// Minimum interactive area. Icon glyphs size themselves with
    /// `.imageScale`, which tracks Dynamic Type; fixed point sizes do not.
    public static let hit: CGFloat = 44
}

/// Subtle motion (dial 3). Pair with `accessibilityReduceMotion`.
public enum ClusterFuckMotion {
    public static let short: Double = 0.18
    public static let standard: Double = 0.22
    /// Emphasis reduction for disabled controls.
    public static let disabledOpacity: Double = 0.4

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

/// One scale, five steps. Every step is a Dynamic Type text style, so the whole
/// HUD scales with the user's setting instead of pinning to a point size.
///
/// `metric` is the only dominant step and it belongs to σ_irr — the one number
/// the whole app exists to show. Everything else is support.
public enum ClusterFuckType {
    /// The primary readout. Mono so digits do not jitter as the value updates.
    public static var metric: Font { .system(.largeTitle, design: .monospaced).weight(.semibold).monospacedDigit() }
    /// The primary readout on the wrist, where largeTitle will not fit.
    public static var metricCompact: Font { .system(.title2, design: .monospaced).weight(.semibold).monospacedDigit() }
    public static var display: Font { .system(.title2, design: .default).weight(.semibold) }
    public static var headline: Font { .headline }
    public static var body: Font { .body }
    public static var caption: Font { .caption }
    /// The smallest step. Still a text style, so it honours Dynamic Type.
    public static var micro: Font { .caption2 }
    /// Inline numerals in supporting copy.
    public static var mono: Font { .body.monospacedDigit().weight(.medium) }
    /// Section headers and badges.
    public static var label: Font { .caption.weight(.semibold) }
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
    /// A custom `ButtonStyle` does not inherit the system's disabled dimming, and
    /// a filled label paints its own background — so without this a disabled
    /// Minimize button is pixel-identical to a live one.
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .scaleEffect(isEnabled && configuration.isPressed ? pressedScale : 1)
            .opacity(opacity)
            .animation(
                ClusterFuckMotion.animation(reduceMotion: reduceMotion, duration: ClusterFuckMotion.short),
                value: configuration.isPressed
            )
            .animation(
                ClusterFuckMotion.animation(reduceMotion: reduceMotion, duration: ClusterFuckMotion.short),
                value: isEnabled
            )
    }

    /// `disabledOpacity` matches the platform convention. WCAG 1.4.3 exempts
    /// inactive controls from the contrast minimum, and the checklist wants
    /// disabled to be unmistakably de-emphasised.
    private var opacity: Double {
        guard isEnabled else { return ClusterFuckMotion.disabledOpacity }
        return configuration.isPressed ? 0.92 : 1
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
        make(light: light, dark: dark, lightAlpha: alpha, darkAlpha: alpha)
    }

    /// Per-theme alpha: the same opacity reads weaker over a light ground, so
    /// the violet washes canon uses for borders lift slightly in light mode.
    public static func make(light: UInt32, dark: UInt32, lightAlpha: Double, darkAlpha: Double) -> Color {
        #if os(macOS)
        return Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let darkMode = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let rgba = ClusterFuckRGBA(hex: darkMode ? dark : light, alpha: darkMode ? darkAlpha : lightAlpha)
            return NSColor(srgbRed: rgba.red, green: rgba.green, blue: rgba.blue, alpha: rgba.alpha)
        }))
        #elseif os(watchOS)
        // watchOS has no dynamic UIColor provider; use the approved dark wrist palette.
        return ClusterFuckRGBA(hex: dark, alpha: darkAlpha).color
        #elseif canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let rgba = ClusterFuckRGBA(
                hex: isDark ? dark : light,
                alpha: isDark ? darkAlpha : lightAlpha
            )
            return UIColor(red: rgba.red, green: rgba.green, blue: rgba.blue, alpha: rgba.alpha)
        })
        #else
        return ClusterFuckRGBA(hex: dark, alpha: darkAlpha).color
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

    /// Violet wash, not a neutral rule. Decorative container edges and gauge tracks.
    static var clusterFuckBorder: Color {
        ClusterFuckAdaptiveColor.make(
            light: ClusterFuckPalette.border,
            dark: ClusterFuckPalette.border,
            lightAlpha: ClusterFuckPalette.lightBorderAlpha,
            darkAlpha: ClusterFuckPalette.darkBorderAlpha
        )
    }

    // Key colours. Each resolves to its light-ground variant in light mode so the
    // quantity stays legible; hue and chroma — the identity — never change.

    /// ΔS · configurational entropy
    static var clusterFuckPrimary: Color {
        ClusterFuckAdaptiveColor.make(light: ClusterFuckPalette.primaryLight, dark: ClusterFuckPalette.primary)
    }
    /// ΔS_vib · vibrational · environment
    static var clusterFuckSecondary: Color {
        ClusterFuckAdaptiveColor.make(light: ClusterFuckPalette.secondaryLight, dark: ClusterFuckPalette.secondary)
    }
    /// ΔH · enthalpy · closure
    static var clusterFuckAccent: Color {
        ClusterFuckAdaptiveColor.make(light: ClusterFuckPalette.accentLight, dark: ClusterFuckPalette.accent)
    }
    /// ΔG · free energy · stats
    static var clusterFuckTangerine: Color {
        ClusterFuckAdaptiveColor.make(light: ClusterFuckPalette.tangerineLight, dark: ClusterFuckPalette.tangerine)
    }
    /// Baseline · apo · reference
    static var clusterFuckMagnesium: Color {
        ClusterFuckAdaptiveColor.make(light: ClusterFuckPalette.magnesiumLight, dark: ClusterFuckPalette.magnesium)
    }
    /// Receptor · elevated σ_irr
    static var clusterFuckWarning: Color {
        ClusterFuckAdaptiveColor.make(light: ClusterFuckPalette.warningLight, dark: ClusterFuckPalette.warning)
    }
    /// T · fail. Canon holds firetruck to 12px and up — use `clusterFuckFailText`
    /// for anything smaller.
    static var clusterFuckDestructive: Color {
        ClusterFuckAdaptiveColor.make(light: ClusterFuckPalette.failTextLight, dark: ClusterFuckPalette.destructive)
    }
    /// `--state-fail-text`. Lifted on dark, darkened on light; for small labels.
    static var clusterFuckFailText: Color {
        ClusterFuckAdaptiveColor.make(light: ClusterFuckPalette.failTextLight, dark: ClusterFuckPalette.failTextDark)
    }

    /// Ink on the mint CTA fill — 11.73:1. Never white on mint.
    static var clusterFuckOnAccent: Color {
        ClusterFuckRGBA(hex: ClusterFuckPalette.darkBackground).color
    }

    // ───────── Fill roles ─────────
    // A key colour used as a *fill* does not take the light-ground variant.
    // The light variants exist for foreground-on-ground contrast; when the
    // colour is the ground, contrast is measured against the label sitting on
    // it. Swapping the fill to the darkened mint drops the CTA from 11.73:1 to
    // 3.96:1 — the variant solves a problem the fill does not have.
    /// ΔH fill for the primary CTA. True mint on both grounds.
    static var clusterFuckAccentFill: Color {
        ClusterFuckRGBA(hex: ClusterFuckPalette.accent).color
    }
}

/// Button roles. A custom `ButtonStyle` replaces the platform chrome wholesale,
/// so without an explicit role every secondary control renders as bare text
/// with no affordance at all.
public enum ClusterFuckButtonRole: Sendable {
    /// Mint fill, ink label. One per screen.
    case primary
    /// Violet-wash outline, ink label. Everything else.
    case secondary
}

/// The one button style. Carries chrome, press feedback, and disabled
/// de-emphasis together so they cannot drift apart.
public struct ClusterFuckButtonStyle: ButtonStyle {
    public var role: ClusterFuckButtonRole
    public var fillsWidth: Bool

    public init(_ role: ClusterFuckButtonRole = .secondary, fillsWidth: Bool = false) {
        self.role = role
        self.fillsWidth = fillsWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        ClusterFuckButtonStyleBody(configuration: configuration, role: role, fillsWidth: fillsWidth)
    }
}

private struct ClusterFuckButtonStyleBody: View {
    let configuration: ButtonStyleConfiguration
    let role: ClusterFuckButtonRole
    let fillsWidth: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(ClusterFuckType.body.weight(.medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, ClusterFuckSpacing.md)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: ClusterFuckIconSize.hit)
            .background(background, in: shape)
            .overlay { if role == .secondary { shape.strokeBorder(border, lineWidth: 1) } }
            .contentShape(shape)
            // scaleEffect is a transform, so the pressed state never moves
            // surrounding content.
            .scaleEffect(isEnabled && configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : ClusterFuckMotion.disabledOpacity)
            .animation(motion, value: configuration.isPressed)
            .animation(motion, value: isEnabled)
    }

    private var motion: Animation? {
        ClusterFuckMotion.animation(reduceMotion: reduceMotion, duration: ClusterFuckMotion.short)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: ClusterFuckRadius.sm, style: .continuous)
    }

    private var foreground: Color {
        role == .primary ? .clusterFuckOnAccent : .clusterFuckInk
    }

    private var background: Color {
        switch role {
        case .primary:
            return configuration.isPressed ? .clusterFuckAccentFill.opacity(0.85) : .clusterFuckAccentFill
        case .secondary:
            return configuration.isPressed ? .clusterFuckBorder.opacity(0.5) : .clear
        }
    }

    private var border: Color { .clusterFuckBorder }
}

/// σ_irr band.
///
/// The band is the app's primary state and it must never be carried by hue
/// alone — roughly 1 in 12 men cannot separate the mint/strawberry pair, and
/// the whole gauge is unreadable on a greyscale wrist face. Each band
/// therefore ships a `symbol` and a `label` alongside its `color`, and the
/// HUD renders all three.
public enum ClusterFuckSigmaBand: String, Sendable, CaseIterable {
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

    /// Redundant encoding #1 — shape. Outline SF Symbols, one family, no emoji.
    public var symbol: String {
        switch self {
        case .unknown: return "questionmark.circle"
        case .closed: return "checkmark.circle"
        case .settling: return "arrow.down.right.circle"
        case .elevated: return "exclamationmark.triangle"
        }
    }

    /// Redundant encoding #2 — text. These are the existing domain terms, the
    /// same ones already spoken in the accessibility label.
    public var label: String {
        switch self {
        case .unknown: return "Unknown"
        case .closed: return "Closed"
        case .settling: return "Settling"
        case .elevated: return "Elevated"
        }
    }

    /// The gauge track is dashed when the value is unknown, so "no reading"
    /// never reads as "a reading of zero".
    public var isKnown: Bool { self != .unknown }
}
