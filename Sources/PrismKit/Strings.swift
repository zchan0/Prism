import Foundation

// Keys are the English text, the same strings Resources/Localizable.xcstrings keys on. `scripts/package.sh` compiles
// one catalog into the app bundle, and `String(localized:)` finds it from any module, so every tool shares one file.
public enum Strings {
    public static let appName = "Prism"

    public static let settings = String(localized: "Settings…")
    public static let quit = String(localized: "Quit Prism")
    public static let close = String(localized: "Close")
    public static let done = String(localized: "Done")
    public static let cancel = String(localized: "Cancel")
    public static let generalTab = String(localized: "General")
    public static let toolsTab = String(localized: "Tools")
    public static let aboutTab = String(localized: "About")
    public static let menuBar = String(localized: "Menu bar")
    public static let showInMenuBar = String(localized: "Show its own icon")
    public static let hubOnly = String(localized: "Only in the panel")
    public static let hubMenuBar = String(localized: "Show the Prism icon in the menu bar")
    public static let hubMenuBarNote = String(localized: "The panel is always reachable with the shortcut, even with the icon hidden.")
    public static let openSettings = String(localized: "Settings…")
    public static let openHub = String(localized: "Open Prism")
    public static func openTool(_ title: String) -> String { String(localized: "Open \(title)") }
    public static let turnOn = String(localized: "On")
    public static let turnOff = String(localized: "Off")
    public static let toolsSection = String(localized: "Tools")
    public static let toolsFooter = String(localized: "Turned-off tools stop running and keep their settings.")
    public static let noTools = String(localized: "No tools are on")
    public static let shortcuts = String(localized: "Shortcuts")
    public static let togglePanelShortcut = String(localized: "Open or close the panel")
    public static let loginItem = String(localized: "Open at login")
    public static let loginItemNeedsApproval = String(localized: "Allow it in System Settings → General → Login Items")
    public static let version = String(localized: "Version %@")
    public static let aboutTagline = String(localized: "One menu bar app, a handful of small tools.")
}
