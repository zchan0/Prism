import AppKit

enum Palette {
    static let ink = dynamic(light: rgb(0x1D1D1F), dark: rgb(0xF5F5F7))
    static let ink2 = dynamic(light: rgb(0x56565B), dark: label(0.70))
    static let ink3 = dynamic(light: rgb(0x6A6A6F), dark: label(0.56))
    static let hair = dynamic(light: black(0.08), dark: white(0.08))
    static let sun = dynamic(light: rgb(0xFF9F0A), dark: rgb(0xFFB340))
    static let sunDeep = dynamic(light: rgb(0xFF7A00), dark: rgb(0xFF9500))
    static let sunPale = dynamic(light: rgb(0xFFD27A), dark: rgb(0xFFE0A3))
    static let moon = dynamic(light: rgb(0x6E7B9A), dark: rgb(0x9DA9C7))
    static let chip = dynamic(light: black(0.055), dark: white(0.09))
    static let chipInk = dynamic(light: rgb(0x3A3A3E), dark: label(0.86))
    static let card = dynamic(light: white(0.80), dark: white(0.07))
    static let cardHover = dynamic(light: white(0.96), dark: white(0.11))
    static let cardBorder = dynamic(light: black(0.055), dark: white(0.08))
    static let panelFill = dynamic(light: rgb(0xF7F7FA), dark: rgb(0x1D1E23))
    static let panelBorder = dynamic(light: white(0.65), dark: white(0.10))
    static let rowHover = dynamic(light: black(0.045), dark: white(0.06))
    static let onFill = dynamic(light: rgb(0xFFFFFF), dark: rgb(0x1E1F24))
    static let onWarm = rgb(0x3A2500)
    static let dim = dynamic(light: black(0.22), dark: white(0.24))
    static let good = dynamic(light: rgb(0x2E9E5B), dark: rgb(0x4CD07D))

    private static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
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
