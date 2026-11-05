import Foundation

/// What the menu bar shows: whether the Mac is kept awake, and the countdown when the person asked for it.
struct MenuBarState: Equatable, Sendable {
    enum Mode: Equatable, Sendable {
        /// The Mac may sleep.
        case asleep
        /// Awake, with no timer set.
        case forever
        /// Awake, counting down.
        case counting(remaining: Int)
    }

    var mode: Mode
    var showsTime: Bool

    var symbolName: String { "wand.and.stars" }

    /// The wand shows its stars only while the Mac is kept awake.
    var isLit: Bool {
        mode != .asleep
    }

    var timeText: String? {
        guard showsTime, case .counting(let remaining) = mode else { return nil }
        return TimeText.compact(TimeInterval(remaining))
    }

    var accessibilityText: String {
        switch mode {
        case .asleep: LumosStrings.sleeping
        case .forever: LumosStrings.awake
        case .counting(let remaining): LumosStrings.inTime(TimeText.remaining(TimeInterval(remaining)))
        }
    }
}
