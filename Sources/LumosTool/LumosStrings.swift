import Foundation

// Keys are the English text, the same strings Resources/Localizable.xcstrings keys on.
// scripts/package.sh compiles the catalog into the app; `swift run` and `swift test` have no catalog,
// so every string falls back to English there.
public enum LumosStrings {
    public static let tagline = String(localized: "Keeps this Mac awake, for a while or until you stop it.")
    public static let awake = String(localized: "Awake")
    public static let sleeping = String(localized: "Sleeping")
    public static let notKeepingAwake = String(localized: "Not keeping awake")
    public static let keepingThisMacAwake = String(localized: "Keeping this Mac awake")
    public static let untilTurnedOff = String(localized: "Until you turn it off")
    public static let sleepsAsUsual = String(localized: "This Mac sleeps as usual")
    public static let keepThisMacAwake = String(localized: "Keep this Mac awake")
    public static let howLong = String(localized: "How long")
    public static let untilStopped = String(localized: "Until I stop it")
    public static let cannotStart = String(localized: "Could not keep this Mac awake")
    public static func inTime(_ text: String) -> String { String(localized: "\(text) left") }
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
    public static func lowBatteryStopsAt(_ level: Int) -> String {
        String(localized: "Stops at \(level)% battery")
    }
    public static let screen = String(localized: "Screen")
    public static let screenStaysOn = String(localized: "Stays on")
    public static let screenCanTurnOff = String(localized: "Can turn off")
    public static let lidClosedOption = String(localized: "Lid closed")
    public static let lidStaysAwake = String(localized: "Stays awake")
    public static let lidSleeps = String(localized: "Sleeps")
    public static let lidClosed = String(localized: "Keep running with the lid closed")
    public static let lidClosedNote = String(localized: "Asks for your password once, then disables lid sleep until the session ends.")
    public static let lidChanging = String(localized: "Changing…")
    public static let cancel = String(localized: "Cancel")
    public static let continueButton = String(localized: "Continue")
    public static let lengthPicker = String(localized: "Default length")
    public static let sessions = String(localized: "Sessions")
    public static let lowBatteryStops = String(localized: "Stop when the battery falls to")
    public static let lowBatteryOff = String(localized: "Never")
    public static func percent(_ value: Int) -> String { String(localized: "\(value)%") }
    public static let notifiesWhenTimerEnds = String(localized: "Tell me when a session ends")
    public static let notifiesWhenBatteryLow = String(localized: "Tell me when the battery stops it")
    public static let menuBarTime = String(localized: "Show the time left")
    public static let notificationTimerTitle = String(localized: "Awake time is up")
    public static let notificationTimerBody = String(localized: "Prism let your Mac sleep again.")
    public static let notificationBatteryTitle = String(localized: "Battery is low")
    public static func notificationBatteryBody(_ level: Int) -> String {
        String(localized: "At \(level)%, Prism stopped keeping your Mac awake.")
    }
    public static let adminPasswordRequired = String(localized: "An administrator password is needed to change lid sleep.")
    public static func lidCommandFailed(_ detail: String) -> String {
        String(localized: "pmset refused the change: \(detail)")
    }
    public static let lidHelperUnavailable = String(localized: "The lid helper could not be installed.")
    public static let lidChangeTimedOut = String(localized: "The lid setting did not change. Try again, or turn it off in System Settings → Battery.")
}
