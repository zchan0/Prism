import Foundation

enum SessionLength: Int, CaseIterable, Identifiable, Sendable {
    case thirtyMinutes = 30
    case oneHour = 60
    case twoHours = 120
    case forever = 0

    var id: Int { rawValue }

    /// Until stopped comes first: it is both the default and the one pick that never surprises anybody.
    static var displayOrder: [SessionLength] { [.forever, .thirtyMinutes, .oneHour, .twoHours] }

    var duration: TimeInterval? {
        self == .forever ? nil : TimeInterval(rawValue * 60)
    }
}

// Pure formatting so the menu bar, the panel and the pet all read the same clock.
enum TimeText {
    /// "4:09" or "1:04:09" for the countdown shown inside the app.
    static func countdown(_ remaining: TimeInterval) -> String {
        let seconds = max(0, Int(remaining.rounded(.up)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let rest = seconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, rest)
            : String(format: "%d:%02d", minutes, rest)
    }

    /// "42m", "1:02" or "42s" next to the menu bar sun, where every point of width counts.
    static func compact(_ remaining: TimeInterval) -> String {
        let seconds = max(0, Int(remaining.rounded(.up)))
        if seconds < 60 { return "\(seconds)s" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return hours > 0 ? String(format: "%d:%02d", hours, minutes) : "\(minutes)m"
    }

    /// "41 min", "1 hr 2 min", "less than a minute" for prose.
    static func remaining(_ remaining: TimeInterval) -> String {
        let seconds = max(0, Int(remaining.rounded(.up)))
        if seconds < 60 { return Strings.lessThanAMinute }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return minutes > 0 ? Strings.hoursMinutes(hours, minutes) : Strings.hoursOnly(hours)
        }
        return Strings.minutesOnly(minutes)
    }
}
