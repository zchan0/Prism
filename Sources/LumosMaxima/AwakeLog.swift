import Foundation

/// Awake time is the only currency the pet earns, so it is tracked per calendar day.
@MainActor
@Observable
final class AwakeLog {
    private(set) var totalToday: TimeInterval = 0
    private(set) var petCount: Int = 0

    private let defaults: UserDefaults
    private let calendar: Calendar
    private static let dayKey = "awakeLog.day"
    private static let secondsKey = "awakeLog.seconds"
    private static let petCountKey = "petCount"

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        petCount = defaults.integer(forKey: Self.petCountKey)
        loadToday()
    }

    func add(_ duration: TimeInterval) {
        guard duration > 0 else { return }
        rollOverIfNeeded()
        totalToday += duration
        defaults.set(totalToday, forKey: Self.secondsKey)
    }

    func reset() {
        totalToday = 0
        petCount = 0
        defaults.set(0, forKey: Self.secondsKey)
        defaults.set(0, forKey: Self.petCountKey)
    }

    func pet() {
        petCount += 1
        defaults.set(petCount, forKey: Self.petCountKey)
    }

    /// Live total including the session still running.
    func todayIncluding(_ running: TimeInterval) -> TimeInterval {
        rollOverIfNeeded()
        return totalToday + max(0, running)
    }

    private func loadToday() {
        rollOverIfNeeded()
        totalToday = defaults.double(forKey: Self.secondsKey)
    }

    private func rollOverIfNeeded() {
        let today = calendar.startOfDay(for: Date())
        let stored = defaults.object(forKey: Self.dayKey) as? Date
        guard stored.map({ calendar.startOfDay(for: $0) != today }) ?? true else { return }
        defaults.set(today, forKey: Self.dayKey)
        // A day that already passed should start from zero even if the app stayed open overnight.
        if stored != nil {
            totalToday = 0
            defaults.set(0, forKey: Self.secondsKey)
        }
    }
}
