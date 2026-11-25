import Foundation

public enum SessionLength: Int, CaseIterable, Identifiable, Sendable {
    case thirtyMinutes = 30
    case oneHour = 60
    case twoHours = 120
    case forever = 0

    public var id: Int { rawValue }

    /// Until stopped comes first: it is both the default and the one pick that never surprises anybody.
    public static var displayOrder: [SessionLength] { [.forever, .thirtyMinutes, .oneHour, .twoHours] }

    public var duration: TimeInterval? {
        self == .forever ? nil : TimeInterval(rawValue * 60)
    }
}

// Pure formatting so the menu bar and the panel read the same clock.
enum TimeText {
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
        if seconds < 60 { return LumosStrings.lessThanAMinute }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return minutes > 0 ? LumosStrings.hoursMinutes(hours, minutes) : LumosStrings.hoursOnly(hours)
        }
        return LumosStrings.minutesOnly(minutes)
    }
}
