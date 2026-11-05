import Foundation
import IOKit
import IOKit.ps

/// The battery: the charge from IOPowerSources, the health from the battery controller's registry entry.
public struct BatteryReading: Equatable, Sendable {
    public var level: Int
    public var isCharging: Bool
    public var isOnAC: Bool
    public var hasBattery: Bool
    public var cycleCount: Int?
    /// Today's full charge as a percentage of the capacity the battery was designed for.
    public var maximumCapacity: Int?

    public var reading: Reading? {
        guard hasBattery else { return nil }
        return Reading(
            kind: .battery,
            value: VitalsStrings.percent(level),
            detail: isCharging ? VitalsStrings.charging : (isOnAC ? VitalsStrings.pluggedIn : VitalsStrings.onBattery),
            fraction: Double(level) / 100,
            isTight: level <= 20 && !isOnAC,
            note: healthNote
        )
    }

    var healthNote: String? {
        let parts = [
            maximumCapacity.map(VitalsStrings.maximumCapacity),
            cycleCount.map(VitalsStrings.cycles),
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// A new battery can hold slightly more than it was designed for; the system shows that as 100%, and so does this.
    static func maximumCapacity(fullCharge: Int, design: Int) -> Int? {
        guard design > 0, fullCharge > 0 else { return nil }
        return min(100, Int((Double(fullCharge) / Double(design) * 100).rounded()))
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
        if result.hasBattery {
            readHealth(into: &result)
        }
        return result
    }

    /// IOPowerSources has no cycle count or capacity, and its own health key disagrees with System Information, so
    /// these come straight from the `AppleSmartBattery` registry entry, the same one `ioreg` prints.
    private static func readHealth(into result: inout BatteryReading) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != IO_OBJECT_NULL else { return }
        defer { IOObjectRelease(service) }
        func integer(_ key: String) -> Int? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? Int
        }
        result.cycleCount = integer("CycleCount")
        if let fullCharge = integer("AppleRawMaxCapacity"), let design = integer("DesignCapacity") {
            result.maximumCapacity = maximumCapacity(fullCharge: fullCharge, design: design)
        }
    }
}
