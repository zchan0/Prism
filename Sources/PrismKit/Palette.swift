import AppKit

public enum Palette {
    public static let ink = dynamic(light: rgb(0x1D1D1F), dark: rgb(0xF5F5F7))
    public static let ink2 = dynamic(light: rgb(0x56565B), dark: label(0.76))
    public static let ink3 = dynamic(light: rgb(0x6A6A6F), dark: label(0.62))
    public static let hair = dynamic(light: black(0.08), dark: white(0.09))
    public static let chip = dynamic(light: black(0.06), dark: white(0.10))
    /// The track of a segmented control and of a reading's bar.
    public static let well = dynamic(light: black(0.06), dark: white(0.07))
    /// What sits on a well, such as the selected segment.
    public static let raised = dynamic(light: rgb(0xFFFFFF), dark: white(0.16))
    public static let card = dynamic(light: white(0.76), dark: white(0.065))
    public static let cardBorder = dynamic(light: black(0.05), dark: white(0.08))
    public static let hover = dynamic(light: black(0.045), dark: white(0.07))
    public static let switchOff = dynamic(light: black(0.15), dark: white(0.20))
    public static let key = dynamic(light: rgb(0xFFFFFF), dark: white(0.10))
    public static let keyBorder = dynamic(light: black(0.14), dark: white(0.16))
    /// A group of rows on a panel's glass, in place of a card: thin enough for the glass to show through.
    public static let plate = dynamic(light: white(0.14), dark: white(0.06))
    /// A keycap on a panel's glass.
    public static let keyOnGlass = dynamic(light: white(0.45), dark: white(0.08))
    /// The ground of the Prism window, behind its cards.
    public static let window = dynamic(light: rgb(0xF3F4F7), dark: rgb(0x222328))
    /// Close to running out, such as a nearly full disk.
    public static let warning = dynamic(light: rgb(0xFF7A00), dark: rgb(0xFF9500))

    /// The system accent: a switch that is on, a selected row, a shortcut being recorded.
    public static let accent = NSColor.controlAccentColor
    public static let selection = NSColor(name: nil) { appearance in
        NSColor.controlAccentColor.withAlphaComponent(isDark(appearance) ? 0.30 : 0.14)
    }
    /// Text in the accent color on `selection`, darker in light mode and lighter in dark mode so it stays legible.
    public static let accentInk = NSColor(name: nil) { appearance in
        let dark = isDark(appearance)
        guard let accent = NSColor.controlAccentColor.usingColorSpace(.sRGB) else { return .controlAccentColor }
        return accent.blended(withFraction: dark ? 0.4 : 0.18, of: dark ? .white : .black) ?? accent
    }

    /// Lumos's card while it keeps the Mac awake.
    public static let lumosWash = dynamic(light: rgb(0xFF9F0A, alpha: 0.13), dark: rgb(0xFFB340, alpha: 0.13))
    public static let lumosLine = dynamic(light: rgb(0xD67800, alpha: 0.34), dark: rgb(0xFFB340, alpha: 0.40))
    /// Vitals' reading bars.
    public static let meter = dynamic(light: rgb(0x2E9E5B), dark: rgb(0x4CD07D))

    public static let lumos = ToolTint(
        glyph: dynamic(light: rgb(0xB86200), dark: rgb(0xFFB340)),
        fill: dynamic(light: rgb(0xFF9F0A, alpha: 0.20), dark: rgb(0xFFB340, alpha: 0.18))
    )
    public static let vitals = ToolTint(
        glyph: dynamic(light: rgb(0x1F7F47), dark: rgb(0x4CD07D)),
        fill: dynamic(light: rgb(0x2E9E5B, alpha: 0.17), dark: rgb(0x4CD07D, alpha: 0.16))
    )
    public static let portkey = ToolTint(
        glyph: dynamic(light: rgb(0x0A66D8), dark: rgb(0x5AA9FF)),
        fill: dynamic(light: rgb(0x0A84FF, alpha: 0.15), dark: rgb(0x0A84FF, alpha: 0.22))
    )
    public static let pensieve = ToolTint(
        glyph: dynamic(light: rgb(0x7446CF), dark: rgb(0xB79CFF)),
        fill: dynamic(light: rgb(0x895AF6, alpha: 0.16), dark: rgb(0x895AF6, alpha: 0.24))
    )
    /// For a tool that is turned off, and for Prism itself.
    public static let neutral = ToolTint(glyph: ink3, fill: chip)

    private static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    private static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            isDark(appearance) ? dark : light
        }
    }

    private static func rgb(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    private static func label(_ alpha: CGFloat) -> NSColor { rgb(0xEBEBF5, alpha: alpha) }
    private static func black(_ alpha: CGFloat) -> NSColor { NSColor(srgbRed: 0, green: 0, blue: 0, alpha: alpha) }
    private static func white(_ alpha: CGFloat) -> NSColor { NSColor(srgbRed: 1, green: 1, blue: 1, alpha: alpha) }
}

/// A tool's color: its symbol, and the tile behind it.
public struct ToolTint: Sendable {
    public let glyph: NSColor
    public let fill: NSColor

    public init(glyph: NSColor, fill: NSColor) {
        self.glyph = glyph
        self.fill = fill
    }
}
