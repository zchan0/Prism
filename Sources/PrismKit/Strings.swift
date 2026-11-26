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
    public static let tagline = String(localized: "A small toolbox in the menu bar")
    public static let appearance = String(localized: "Appearance")
    public static let appearanceSystem = String(localized: "System")
    public static let appearanceLight = String(localized: "Light")
    public static let appearanceDark = String(localized: "Dark")

    public static let about = String(localized: "About")
    public static let checkForUpdates = String(localized: "Check for updates")
    public static let daily = String(localized: "Daily")
    public static let weekly = String(localized: "Weekly")
    public static let monthly = String(localized: "Monthly")
    public static let never = String(localized: "Never")
    public static let installAutomatically = String(localized: "Install updates automatically")
    public static let installAutomaticallyOn = String(localized: "Installs when Prism is idle, then reopens it.")
    public static let installAutomaticallyOff = String(localized: "Only tells you about a new version. You choose when to install.")
    public static let releaseNotes = String(localized: "Release notes")
    public static let updateAvailableBadge = String(localized: "Update available")
    public static let updateReadyBadge = String(localized: "Update ready")

    public static let checkNow = String(localized: "Check Now")
    public static let update = String(localized: "Update")
    public static let cancel = String(localized: "Cancel")
    public static let installAndRelaunch = String(localized: "Install and Relaunch")
    public static let tryAgain = String(localized: "Try Again")
    public static let downloadAgain = String(localized: "Download Again")
    public static let download = String(localized: "Download")
    public static let whatsNew = String(localized: "What's new")
    public static let downloadFromGitHub = String(localized: "download it from GitHub")
    public static let viewOnGitHub = String(localized: "View on GitHub")

    public static func upToDate(lastChecked: String) -> String { String(localized: "Up to date · Last checked \(lastChecked)") }
    public static func automaticChecksOff(lastChecked: String) -> String {
        String(localized: "Automatic checks are off · Last checked \(lastChecked)")
    }
    public static let notCheckedYet = String(localized: "Not checked yet")
    public static let checkingForUpdates = String(localized: "Checking for updates…")
    public static func youHave(_ version: String) -> String { String(localized: "You have \(version)") }
    public static func updateAvailable(_ version: String) -> String { String(localized: "Prism \(version) is available") }
    public static func downloading(_ version: String) -> String { String(localized: "Downloading Prism \(version)") }
    public static let installsWhenIdle = String(localized: "Installs when Prism is idle")
    public static let installsWhenDownloaded = String(localized: "Installs and reopens Prism when the download finishes")
    public static func updateReady(_ version: String) -> String { String(localized: "Prism \(version) is ready") }
    public static let installsWhenWindowCloses = String(localized: "Installs when you close this window")
    public static func installsWhenFinished(_ tools: String) -> String { String(localized: "Installs when \(tools) finishes") }
    public static let downloadedAndReady = String(localized: "Downloaded and ready to install")
    public static func installing(_ version: String) -> String { String(localized: "Installing Prism \(version)…") }
    public static let willReopen = String(localized: "Prism will reopen")
    public static func willReopenKeepsRunning(_ tools: String) -> String {
        String(localized: "Prism will reopen. \(tools) keeps running.")
    }
    public static func updated(_ when: String) -> String { String(localized: "Updated \(when)") }
    public static let couldNotCheck = String(localized: "Couldn't check for updates")
    public static func gitHubUnreachable(lastChecked: String) -> String {
        String(localized: "GitHub can't be reached. Last checked \(lastChecked)")
    }
    public static let gitHubUnreachableNeverChecked = String(localized: "GitHub can't be reached.")
    public static func couldNotDownload(_ version: String) -> String { String(localized: "Couldn't download Prism \(version)") }
    public static let downloadStopped = String(localized: "The download stopped. You can also")
    public static func failedVerification(_ version: String) -> String {
        String(localized: "Prism \(version) didn't pass verification")
    }
    public static let downloadDeleted = String(localized: "The download was deleted. Your current version is unchanged.")
    public static func couldNotInstall(_ version: String) -> String { String(localized: "Couldn't install Prism \(version)") }
    public static let versionUnchanged = String(localized: "Your current version is unchanged. You can also")
    public static let cannotReplaceItself = String(
        localized: "Prism can't replace itself here. Move it to the Applications folder with Finder, or download the new version."
    )
    public static let developmentBuild = String(localized: "Development builds don't check for updates")

    public static let experiments = String(localized: "Experiments")
    public static let experimentsNote = String(localized: "For trying looks. This section goes away before release.")
    public static let lookGrouping = String(localized: "Panel groups")
    public static let lookInk = String(localized: "Panel text")
    public static let lookBackground = String(localized: "Panel background")
    public static let lookSidebar = String(localized: "Window sidebar")
    public static let lookSidebarNote = String(localized: "Takes effect after Prism restarts.")
    public static let lookCards = String(localized: "Cards")
    public static let lookPlates = String(localized: "Plates")
    public static let lookBare = String(localized: "Bare")
    public static let lookPalette = String(localized: "Palette")
    // Its own key: the appearance's "System" reads differently in Chinese.
    public static let lookSystem = String(localized: "look.system", defaultValue: "System")
    public static let lookGlass = String(localized: "Glass")
    public static let lookMaterial = String(localized: "Material")
    public static let lookCustom = String(localized: "Custom")

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
