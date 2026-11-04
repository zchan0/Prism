import Foundation
import Observation

@MainActor
@Observable
final class Preferences {
    private enum Key {
        static let showsPet = "tools.awake.showsPet"
        static let showsTimeInMenuBar = "tools.awake.showsTimeInMenuBar"
        static let keepsDisplayAwake = "tools.awake.keepsDisplayAwake"
        static let keepsAwakeWithLidClosed = "tools.awake.keepsAwakeWithLidClosed"
        static let lastLength = "tools.awake.lastLength"
        static let lengthDefaultMigrated = "tools.awake.lengthDefaultMigrated"
        static let lowBatteryThreshold = "tools.awake.lowBatteryThreshold"
        static let notifiesWhenTimerEnds = "tools.awake.notifiesWhenTimerEnds"
        static let notifiesWhenBatteryLow = "tools.awake.notifiesWhenBatteryLow"
        static let petOriginX = "tools.awake.petOriginX"
        static let petOriginY = "tools.awake.petOriginY"
    }

    var showsPet: Bool { didSet { defaults.set(showsPet, forKey: Key.showsPet) } }
    var showsTimeInMenuBar: Bool { didSet { defaults.set(showsTimeInMenuBar, forKey: Key.showsTimeInMenuBar) } }
    var keepsDisplayAwake: Bool { didSet { defaults.set(keepsDisplayAwake, forKey: Key.keepsDisplayAwake) } }
    var keepsAwakeWithLidClosed: Bool { didSet { defaults.set(keepsAwakeWithLidClosed, forKey: Key.keepsAwakeWithLidClosed) } }
    var lastLength: SessionLength { didSet { defaults.set(lastLength.rawValue, forKey: Key.lastLength) } }
    var lowBatteryThreshold: LowBatteryThreshold { didSet { defaults.set(lowBatteryThreshold.rawValue, forKey: Key.lowBatteryThreshold) } }
    var notifiesWhenTimerEnds: Bool { didSet { defaults.set(notifiesWhenTimerEnds, forKey: Key.notifiesWhenTimerEnds) } }
    var notifiesWhenBatteryLow: Bool { didSet { defaults.set(notifiesWhenBatteryLow, forKey: Key.notifiesWhenBatteryLow) } }
    var petOrigin: CGPoint? {
        didSet {
            guard let petOrigin else {
                defaults.removeObject(forKey: Key.petOriginX)
                defaults.removeObject(forKey: Key.petOriginY)
                return
            }
            defaults.set(Double(petOrigin.x), forKey: Key.petOriginX)
            defaults.set(Double(petOrigin.y), forKey: Key.petOriginY)
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showsPet = defaults.object(forKey: Key.showsPet) as? Bool ?? true
        showsTimeInMenuBar = defaults.object(forKey: Key.showsTimeInMenuBar) as? Bool ?? true
        keepsDisplayAwake = defaults.object(forKey: Key.keepsDisplayAwake) as? Bool ?? true
        keepsAwakeWithLidClosed = defaults.object(forKey: Key.keepsAwakeWithLidClosed) as? Bool ?? false
        // Until stopped is the default. Builds before 0.1.1 stored a fixed 30 minutes as their default, which nobody
        // picked, so an existing install is moved over once; a length picked after that is kept.
        let storedLength = defaults.object(forKey: Key.lastLength).flatMap { $0 as? Int }.flatMap(SessionLength.init(rawValue:))
        if defaults.bool(forKey: Key.lengthDefaultMigrated) {
            lastLength = storedLength ?? .forever
        } else {
            lastLength = .forever
            defaults.set(true, forKey: Key.lengthDefaultMigrated)
            defaults.set(SessionLength.forever.rawValue, forKey: Key.lastLength)
        }
        lowBatteryThreshold = defaults.object(forKey: Key.lowBatteryThreshold).flatMap { $0 as? Int }.flatMap(LowBatteryThreshold.init(rawValue:)) ?? .twenty
        notifiesWhenTimerEnds = defaults.object(forKey: Key.notifiesWhenTimerEnds) as? Bool ?? true
        notifiesWhenBatteryLow = defaults.object(forKey: Key.notifiesWhenBatteryLow) as? Bool ?? true
        if let x = defaults.object(forKey: Key.petOriginX) as? Double,
           let y = defaults.object(forKey: Key.petOriginY) as? Double {
            petOrigin = CGPoint(x: x, y: y)
        }
    }
}
