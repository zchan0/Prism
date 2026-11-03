import Foundation
import Observation

@MainActor
@Observable
final class Preferences {
    private enum Key {
        static let showsPet = "showsPet"
        static let showsTimeInMenuBar = "showsTimeInMenuBar"
        static let keepsDisplayAwake = "keepsDisplayAwake"
        static let keepsAwakeWithLidClosed = "keepsAwakeWithLidClosed"
        static let lastLength = "lastLength"
        static let lowBatteryThreshold = "lowBatteryThreshold"
        static let notifiesWhenTimerEnds = "notifiesWhenTimerEnds"
        static let notifiesWhenBatteryLow = "notifiesWhenBatteryLow"
        static let petOriginX = "petOriginX"
        static let petOriginY = "petOriginY"
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
        lastLength = defaults.object(forKey: Key.lastLength).flatMap { $0 as? Int }.flatMap(SessionLength.init(rawValue:)) ?? .forever
        lowBatteryThreshold = defaults.object(forKey: Key.lowBatteryThreshold).flatMap { $0 as? Int }.flatMap(LowBatteryThreshold.init(rawValue:)) ?? .twenty
        notifiesWhenTimerEnds = defaults.object(forKey: Key.notifiesWhenTimerEnds) as? Bool ?? true
        notifiesWhenBatteryLow = defaults.object(forKey: Key.notifiesWhenBatteryLow) as? Bool ?? true
        if let x = defaults.object(forKey: Key.petOriginX) as? Double,
           let y = defaults.object(forKey: Key.petOriginY) as? Double {
            petOrigin = CGPoint(x: x, y: y)
        }
    }
}
