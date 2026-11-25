import Foundation

enum PortkeyStrings {
    static func appCount(_ count: Int) -> String {
        switch count {
        case 0: String(localized: "No apps")
        case 1: String(localized: "1 app")
        default: String(localized: "\(count) apps")
        }
    }
    static let tagline = String(localized: "Press a shortcut to jump to an app. Press it again to hide the app.")
    static let apps = String(localized: "Apps")
    static let noShortcut = String(localized: "No shortcut")
    static func goTo(_ name: String) -> String { String(localized: "Go to \(name)") }
    static func usedBy(_ shortcut: String, _ name: String) -> String {
        String(localized: "\(shortcut) is used by \(name)")
    }
    static let editHint = String(localized: "Click a shortcut to change it. Press ⌫ while it records to remove it.")
    static let noAppsYet = String(localized: "No apps yet. Add the apps you switch to most.")
}
