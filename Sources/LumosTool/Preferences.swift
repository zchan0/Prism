import Foundation
import Observation

@MainActor
@Observable
final class Preferences {
    private enum Key {
        static let showsTimeInMenuBar = "tools.lumos.showsTimeInMenuBar"
        static let keepsDisplayAwake = "tools.lumos.keepsDisplayAwake"
        static let keepsAwakeWithLidClosed = "tools.lumos.keepsAwakeWithLidClosed"
        static let lastLength = "tools.lumos.lastLength"
        static let lowBatteryThreshold = "tools.lumos.lowBatteryThreshold"
        static let notifiesWhenTimerEnds = "tools.lumos.notifiesWhenTimerEnds"
        static let notifiesWhenBatteryLow = "tools.lumos.notifiesWhenBatteryLow"
    }

    var showsTimeInMenuBar: Bool { didSet { defaults.set(showsTimeInMenuBar, forKey: Key.showsTimeInMenuBar) } }
    var keepsDisplayAwake: Bool { didSet { defaults.set(keepsDisplayAwake, forKey: Key.keepsDisplayAwake) } }
    var keepsAwakeWithLidClosed: Bool { didSet { defaults.set(keepsAwakeWithLidClosed, forKey: Key.keepsAwakeWithLidClosed) } }
    var lastLength: SessionLength { didSet { defaults.set(lastLength.rawValue, forKey: Key.lastLength) } }
    var lowBatteryThreshold: LowBatteryThreshold { didSet { defaults.set(lowBatteryThreshold.rawValue, forKey: Key.lowBatteryThreshold) } }
    var notifiesWhenTimerEnds: Bool { didSet { defaults.set(notifiesWhenTimerEnds, forKey: Key.notifiesWhenTimerEnds) } }
    var notifiesWhenBatteryLow: Bool { didSet { defaults.set(notifiesWhenBatteryLow, forKey: Key.notifiesWhenBatteryLow) } }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showsTimeInMenuBar = defaults.object(forKey: Key.showsTimeInMenuBar) as? Bool ?? true
        keepsDisplayAwake = defaults.object(forKey: Key.keepsDisplayAwake) as? Bool ?? true
        keepsAwakeWithLidClosed = defaults.object(forKey: Key.keepsAwakeWithLidClosed) as? Bool ?? false
        lastLength = defaults.object(forKey: Key.lastLength).flatMap { $0 as? Int }.flatMap(SessionLength.init(rawValue:)) ?? .forever
        lowBatteryThreshold = defaults.object(forKey: Key.lowBatteryThreshold).flatMap { $0 as? Int }.flatMap(LowBatteryThreshold.init(rawValue:)) ?? .twenty
        notifiesWhenTimerEnds = defaults.object(forKey: Key.notifiesWhenTimerEnds) as? Bool ?? true
        notifiesWhenBatteryLow = defaults.object(forKey: Key.notifiesWhenBatteryLow) as? Bool ?? true
    }
}
