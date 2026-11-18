import Foundation

// Keys are the English text, the same strings Resources/Localizable.xcstrings keys on. `scripts/package.sh` compiles
// one catalog into the app bundle, and `String(localized:)` finds it from any module, so every tool shares one file.
public enum Strings {
    public static let appName = "Prism"

    public static let quit = String(localized: "Quit Prism")
    public static let openHub = String(localized: "Open Prism")
    public static let generalTab = String(localized: "General")
    public static let turnedOn = String(localized: "Turned on")
    public static let showInMenuBar = String(localized: "Show in the menu bar")
    public static let turnedOffNote = String(localized: "Turned off. Its settings are kept.")
    public static let loginItem = String(localized: "Open at login")
    public static let loginItemNeedsApproval = String(localized: "Allow it in System Settings → General → Login Items")
    public static func version(_ version: String) -> String { String(localized: "Version \(version)") }
}
