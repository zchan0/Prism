import Foundation

enum PortkeyStrings {
    static func appCount(_ count: Int) -> String {
        switch count {
        case 0: String(localized: "No apps")
        case 1: String(localized: "1 app")
        default: String(localized: "\(count) apps")
        }
    }
    static let appsAndShortcuts = String(localized: "Apps and shortcuts")
    static let edit = String(localized: "Edit…")
    static let recordShortcut = String(localized: "Record shortcut")
    static let typeShortcut = String(localized: "Type shortcut…")
    static let typeShortcutOrClear = String(localized: "Type shortcut, or ⌫ to clear")
    static func usedBy(_ shortcut: String, _ name: String) -> String {
        String(localized: "\(shortcut) is used by \(name)")
    }
    static let needsModifier = String(localized: "A shortcut needs ⌘, ⌃ or ⌥")
    static let couldNotSetUp = String(localized: "This shortcut could not be set up.")
    static let clearShortcut = String(localized: "Clear shortcut")
    static func remove(_ name: String) -> String { String(localized: "Remove \(name)") }
    static let addApp = String(localized: "Add app")
    static let openApps = String(localized: "Open")
    static let dockApps = String(localized: "Dock")
    static let otherApp = String(localized: "Other…")
    static let howItWorks = String(localized: "Press a shortcut to jump to an app.\nPress it again to hide the app.")
    static let noAppsYet = String(localized: "No apps yet. Add the apps you switch to most.")
}
