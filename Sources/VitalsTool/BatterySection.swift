import Foundation
import IOKit.ps

/// The battery, from IOPowerSources.
public struct BatteryReading: Equatable, Sendable {
    public var level: Int
    public var isCharging: Bool
    public var isOnAC: Bool
    public var hasBattery: Bool

    public var reading: Reading? {
        guard hasBattery else { return nil }
        return Reading(
            kind: .battery,
            value: VitalsStrings.percent(level),
            detail: isCharging ? VitalsStrings.charging : (isOnAC ? VitalsStrings.pluggedIn : VitalsStrings.onBattery),
            fraction: Double(level) / 100,
            isTight: level <= 20 && !isOnAC
        )
    }

    public static func read() -> BatteryReading {
        var result = BatteryReading(level: 0, isCharging: false, isOnAC: false, hasBattery: false)
        result.isOnAC = (IOPSGetProvidingPowerSourceType(nil)?.takeRetainedValue() as String?) == kIOPSACPowerValue
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return result }
        for source in list {
            guard let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  info[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
            result.hasBattery = true
            result.isCharging = info[kIOPSIsChargingKey] as? Bool ?? false
            if let current = info[kIOPSCurrentCapacityKey] as? Int,
               let maximum = info[kIOPSMaxCapacityKey] as? Int, maximum > 0 {
                result.level = Int((Double(current) / Double(maximum) * 100).rounded())
            }
            break
        }
        return result
    }
}
