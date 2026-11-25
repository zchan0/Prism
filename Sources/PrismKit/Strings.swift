import Foundation

// Keys are the English text, the same strings Resources/Localizable.xcstrings keys on. `scripts/package.sh` compiles
// one catalog into the app bundle, and `String(localized:)` finds it from any module, so every tool shares one file.
public enum Strings {
    public static let appName = "Prism"

    public static let quit = String(localized: "Quit Prism")
    public static let quitButton = String(localized: "Quit")
    public static let quitNote = String(localized: "Every tool stops, and the menu bar icons go away.")
    public static let prismSettings = String(localized: "Prism Settings…")
    public static func toolSettings(_ tool: String) -> String { String(localized: "\(tool) settings") }
    public static let tools = String(localized: "Tools")
    public static let general = String(localized: "General")
    public static let off = String(localized: "Off")
    public static let menuBar = String(localized: "Menu Bar")
    public static let showInMenuBar = String(localized: "Show in the menu bar")
    public static let turnedOffNote = String(localized: "Turned off. Its settings are kept.")
    public static let loginItem = String(localized: "Open at login")
    public static let loginItemNeedsApproval = String(localized: "Allow it in System Settings → General → Login Items")
    public static func version(_ version: String) -> String { String(localized: "Version \(version)") }
    public static let appearance = String(localized: "Appearance")
    public static let appearanceSystem = String(localized: "System")
    public static let appearanceLight = String(localized: "Light")
    public static let appearanceDark = String(localized: "Dark")

    public static let addApp = String(localized: "Add App…")
    public static let openApps = String(localized: "Open")
    public static let dockApps = String(localized: "Dock")
    public static let otherApp = String(localized: "Other…")
    public static func remove(_ name: String) -> String { String(localized: "Remove \(name)") }

    public static let addShortcut = String(localized: "Add Shortcut")
    public static let typeShortcut = String(localized: "Type shortcut…")
    public static let shortcutNeedsModifier = String(localized: "A shortcut needs ⌘, ⌃ or ⌥")
    public static let shortcutCouldNotBeSetUp = String(localized: "This shortcut could not be set up.")
    public static let clearShortcut = String(localized: "Clear shortcut")
}
