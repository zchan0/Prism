import Foundation

// Keys are the English text, the same strings Resources/Localizable.xcstrings keys on.
// scripts/package.sh compiles the catalog into the app; `swift run` and `swift test` have no catalog,
// so every string falls back to English there.
public enum AwakeStrings {
    public static let awake = String(localized: "Awake")
    public static let sleeping = String(localized: "Sleeping")
    public static let keepAwake = String(localized: "Keep Awake")
    public static let keepingAwake = String(localized: "Keeping awake")
    public static let stop = String(localized: "Let It Sleep")
    public static let untilStopped = String(localized: "Until I stop it")
    public static let close = String(localized: "Close")
    public static let off = String(localized: "Off")
    public static let noTimer = String(localized: "No timer")
    public static let cannotStart = String(localized: "Could not keep this Mac awake")
    public static func inTime(_ text: String) -> String { String(localized: "\(text) left") }
    public static func awakeFor(_ text: String) -> String { String(localized: "Awake for \(text)") }
    public static let lessThanAMinute = String(localized: "less than a minute")
    public static func minutesOnly(_ minutes: Int) -> String { String(localized: "\(minutes) min") }
    public static func hoursOnly(_ hours: Int) -> String { String(localized: "\(hours) hr") }
    public static func hoursMinutes(_ hours: Int, _ minutes: Int) -> String { String(localized: "\(hours) hr \(minutes) min") }
    public static func minutes(_ minutes: Int) -> String { String(localized: "\(minutes) minutes") }
    public static func hours(_ hours: Int) -> String { String(localized: "\(hours) hours") }
    public static func lengthName(_ length: SessionLength) -> String {
        switch length {
        case .thirtyMinutes: minutes(30)
        case .oneHour: hours(1)
        case .twoHours: hours(2)
        case .forever: untilStopped
        }
    }
    public static func lengthCompact(_ length: SessionLength) -> String {
        switch length {
        case .thirtyMinutes: "30m"
        case .oneHour: "1h"
        case .twoHours: "2h"
        case .forever: "∞"
        }
    }
    public static func awakeNoTimer(_ text: String) -> String { String(localized: "Awake for \(text) with no timer") }
    public static let battery = String(localized: "Battery")
    public static let pluggedIn = String(localized: "Plugged in")
    public static let onBattery = String(localized: "On battery")
    public static let noBattery = String(localized: "No battery")
    public static func batteryLevel(_ level: Int) -> String { String(localized: "\(level)%") }
    public static func lowBatteryStopsAt(_ level: Int) -> String {
        String(localized: "Stops keeping awake at \(level)% to save the battery")
    }
    public static let lidClosed = String(localized: "Keep running with the lid closed")
    public static let lidClosedNote = String(localized: "Asks for your password once, then disables lid sleep until the session ends.")
    public static let lidOn = String(localized: "On")
    public static let lidOff = String(localized: "Off")
    public static let lidChanging = String(localized: "Changing…")
    public static let lidNeedsPermission = String(localized: "Allow lid sleep to change, or System Settings → Energy may be affected.")
    public static let cancel = String(localized: "Cancel")
    public static let continueButton = String(localized: "Continue")
    public static let settings = String(localized: "Settings…")
    public static let quit = String(localized: "Quit LumosMaxima")
    public static let generalTab = String(localized: "General")
    public static let aboutTab = String(localized: "About")
    public static let keepsDisplayAwake = String(localized: "Keep the screen on too")
    public static let keepsDisplayAwakeNote = String(localized: "Off: the Mac stays awake while its screen can turn off.")
    public static let lengthPicker = String(localized: "Default length")
    public static let lowBatteryStops = String(localized: "Stop keeping awake when the battery falls to")
    public static let lowBatteryOff = String(localized: "Never")
    public static func percent(_ value: Int) -> String { String(localized: "\(value)%") }
    public static let notifications = String(localized: "Notifications")
    public static let notifiesWhenTimerEnds = String(localized: "Tell me when the session ends")
    public static let notifiesWhenBatteryLow = String(localized: "Tell me when the battery stops the session")
    public static let shortcuts = String(localized: "Shortcuts")
    public static let toggleShortcut = String(localized: "Start or stop keeping awake")
    public static let menuBarTime = String(localized: "Show the time left in the menu bar")
    public static let petLabel = String(localized: "Show the pet on screen")
    public static let petNote = String(localized: "Drag it anywhere; it naps while the Mac may sleep.")
    public static let loginItem = String(localized: "Open at login")
    public static let loginItemNeedsApproval = String(localized: "Allow it in System Settings → General → Login Items")
    public static let notificationTimerTitle = String(localized: "Awake time is up")
    public static let notificationTimerBody = String(localized: "LumosMaxima let your Mac sleep again.")
    public static let notificationBatteryTitle = String(localized: "Battery is low")
    public static func notificationBatteryBody(_ level: Int) -> String {
        String(localized: "At \(level)%, LumosMaxima stopped keeping your Mac awake.")
    }
    public static let adminPasswordRequired = String(localized: "An administrator password is needed to change lid sleep.")
    public static func lidCommandFailed(_ detail: String) -> String {
        String(localized: "pmset refused the change: \(detail)")
    }
    public static let lidHelperUnavailable = String(localized: "The lid helper could not be installed.")
    public static let lidChangeTimedOut = String(localized: "The lid setting did not change. Try again, or turn it off in System Settings → Battery.")
    public static let yourPet = String(localized: "Your sun")
    public static let yourSun = String(localized: "Your sun")
    public static let petIdle = String(localized: "It hasn’t woken up today")
    public static let petHint = String(localized: "Click to open the controls, drag to move")
    public static let asleepHint = String(localized: "Your Mac may sleep. Tap a length to wake the sun.")
    public static func petAwakeToday(_ text: String) -> String { String(localized: "\(text) awake today") }
    public static func petSessions(_ count: Int) -> String {
        count == 1 ? String(localized: "1 session together") : String(localized: "\(count) sessions together")
    }
    public static func petStageNote(_ stage: SunStage) -> String {
        switch stage {
        case .spark: String(localized: "A spark that sleeps all day")
        case .ember: String(localized: "Warms up after an hour awake")
        case .flare: String(localized: "Shines after three hours")
        case .sol: String(localized: "Blazes after six hours")
        case .nova: String(localized: "Goes supernova after ten hours")
        }
    }
    public static let resetPet = String(localized: "Start the pet over")
    public static let petStagesFooter = String(localized: "It grows every hour it keeps your Mac awake, and naps on days it does not.")
    public static let aboutTagline = String(localized: "A sun that keeps your Mac awake, and gets brighter the longer you work.")
    public static func version(_ version: String) -> String { String(localized: "Version \(version)") }
}
