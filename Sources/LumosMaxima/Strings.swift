import Foundation

// Keys are the English text, the same strings Resources/Localizable.xcstrings keys on.
// scripts/package.sh compiles the catalog into the app; `swift run` and `swift test` have no catalog,
// so every string falls back to English there.
enum Strings {
    static let appName = "LumosMaxima"

    static let awake = String(localized: "Awake")
    static let sleeping = String(localized: "Sleeping")
    static let keepAwake = String(localized: "Keep Awake")
    static let keepingAwake = String(localized: "Keeping awake")
    static let stop = String(localized: "Let It Sleep")
    static let untilStopped = String(localized: "Until I stop it")
    static let cannotStart = String(localized: "Could not keep this Mac awake")

    static func inTime(_ text: String) -> String { String(localized: "\(text) left") }
    static func awakeFor(_ text: String) -> String { String(localized: "Awake for \(text)") }
    static let lessThanAMinute = String(localized: "less than a minute")
    static func minutesOnly(_ minutes: Int) -> String { String(localized: "\(minutes) min") }
    static func hoursOnly(_ hours: Int) -> String { String(localized: "\(hours) hr") }
    static func hoursMinutes(_ hours: Int, _ minutes: Int) -> String { String(localized: "\(hours) hr \(minutes) min") }

    static func minutes(_ minutes: Int) -> String { String(localized: "\(minutes) minutes") }
    static func hours(_ hours: Int) -> String { String(localized: "\(hours) hours") }
    static func lengthName(_ length: SessionLength) -> String {
        switch length {
        case .thirtyMinutes: minutes(30)
        case .oneHour: hours(1)
        case .twoHours: hours(2)
        case .forever: untilStopped
        }
    }
    static func lengthCompact(_ length: SessionLength) -> String {
        switch length {
        case .thirtyMinutes: "30m"
        case .oneHour: "1h"
        case .twoHours: "2h"
        case .forever: "∞"
        }
    }

    static func awakeNoTimer(_ text: String) -> String { String(localized: "Awake for \(text) with no timer") }

    static let battery = String(localized: "Battery")
    static let pluggedIn = String(localized: "Plugged in")
    static let onBattery = String(localized: "On battery")
    static let noBattery = String(localized: "No battery")
    static func batteryLevel(_ level: Int) -> String { String(localized: "\(level)%") }
    static func lowBatteryStopsAt(_ level: Int) -> String {
        String(localized: "Stops keeping awake at \(level)% to save the battery")
    }

    static let lidClosed = String(localized: "Keep running with the lid closed")
    static let lidClosedNote = String(localized: "Asks for your password once, then disables lid sleep until the session ends.")
    static let lidOn = String(localized: "On")
    static let lidOff = String(localized: "Off")
    static let lidChanging = String(localized: "Changing…")
    static let lidNeedsPermission = String(localized: "Allow lid sleep to change, or System Settings → Energy may be affected.")
    static let cancel = String(localized: "Cancel")
    static let continueButton = String(localized: "Continue")

    static let settings = String(localized: "Settings…")
    static let quit = String(localized: "Quit LumosMaxima")

    static let generalTab = String(localized: "General")
    static let aboutTab = String(localized: "About")
    static let keepsDisplayAwake = String(localized: "Keep the screen on too")
    static let keepsDisplayAwakeNote = String(localized: "Off: the Mac stays awake while its screen can turn off.")
    static let lengthPicker = String(localized: "Default length")
    static let lowBatteryStops = String(localized: "Stop keeping awake when the battery falls to")
    static let lowBatteryOff = String(localized: "Never")
    static func percent(_ value: Int) -> String { String(localized: "\(value)%") }
    static let notifications = String(localized: "Notifications")
    static let notifiesWhenTimerEnds = String(localized: "Tell me when the session ends")
    static let notifiesWhenBatteryLow = String(localized: "Tell me when the battery stops the session")
    static let shortcuts = String(localized: "Shortcuts")
    static let toggleShortcut = String(localized: "Start or stop keeping awake")
    static let menuBarTime = String(localized: "Show the time left in the menu bar")
    static let petLabel = String(localized: "Show the pet on screen")
    static let petNote = String(localized: "Drag it anywhere; it naps while the Mac may sleep.")
    static let loginItem = String(localized: "Open at login")
    static let loginItemNeedsApproval = String(localized: "Allow it in System Settings → General → Login Items")

    static let notificationTimerTitle = String(localized: "Awake time is up")
    static let notificationTimerBody = String(localized: "LumosMaxima let your Mac sleep again.")
    static let notificationBatteryTitle = String(localized: "Battery is low")
    static func notificationBatteryBody(_ level: Int) -> String {
        String(localized: "At \(level)%, LumosMaxima stopped keeping your Mac awake.")
    }
    static let adminPasswordRequired = String(localized: "An administrator password is needed to change lid sleep.")
    static func lidCommandFailed(_ detail: String) -> String {
        String(localized: "pmset refused the change: \(detail)")
    }
    static let lidHelperUnavailable = String(localized: "The lid helper could not be installed.")
    static let lidChangeTimedOut = String(localized: "The lid setting did not change. Try again, or turn it off in System Settings → Battery.")

    static let yourPet = String(localized: "Your sun")
    static let petAsleepHint = String(localized: "Tap to wake it up")
    static let asleepHint = String(localized: "Your Mac may sleep. Tap a length to wake the sun.")
    static let petAwakeHint = String(localized: "Tap to let it nap")
    static func petAwakeToday(_ text: String) -> String { String(localized: "\(text) awake today") }
    static func petSessions(_ count: Int) -> String {
        count == 1 ? String(localized: "1 session together") : String(localized: "\(count) sessions together")
    }
    static func petStageNote(_ stage: SunStage) -> String {
        switch stage {
        case .spark: String(localized: "A spark that sleeps all day")
        case .ember: String(localized: "Warms up after an hour awake")
        case .flare: String(localized: "Shines after three hours")
        case .sol: String(localized: "Blazes after six hours")
        case .nova: String(localized: "Goes supernova after ten hours")
        }
    }
    static let resetPet = String(localized: "Start the pet over")
    static let petStagesFooter = String(localized: "It grows every hour it keeps your Mac awake, and naps on days it does not.")
    static let aboutTagline = String(localized: "A sun that keeps your Mac awake, and gets brighter the longer you work.")
    static func version(_ version: String) -> String { String(localized: "Version \(version)") }
}
