import Foundation
import IOKit.ps

struct BatterySnapshot: Equatable, Sendable {
    var hasBattery = false
    var level: Int?
    var isCharging = false
    var isOnAC = false

    var isPluggedIn: Bool { isOnAC || isCharging }
    var isOnBattery: Bool { hasBattery && !isPluggedIn }

    static let unknown = BatterySnapshot()
}

/// The one rule that keeps a long session from flattening the battery.
enum BatteryPolicy {
    static func stopsSession(_ snapshot: BatterySnapshot, threshold: Int?) -> Bool {
        guard let threshold, let level = snapshot.level, snapshot.isOnBattery else { return false }
        return level <= threshold
    }
}

enum LowBatteryThreshold: Int, CaseIterable, Identifiable, Sendable {
    case off = 0
    case ten = 10
    case twenty = 20
    case thirty = 30
    case forty = 40
    case fifty = 50

    var id: Int { rawValue }
    var percent: Int? { self == .off ? nil : rawValue }
}

@MainActor
final class BatteryMonitor {
    private(set) var snapshot = BatterySnapshot.unknown
    var onChange: (@MainActor (BatterySnapshot) -> Void)?

    private var pollTimer: Timer?
    private var powerSource: CFRunLoopSource?

    func start() {
        refresh()
        // Plugging in or unplugging should land in the panel right away; percentage drops are rare enough for a poll.
        if let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            MainActor.assumeIsolated {
                Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue().refresh()
            }
        }, Unmanaged.passUnretained(self).toOpaque()) {
            let source = source.takeRetainedValue()
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            powerSource = source
        }
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer.tolerance = 10
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        if let powerSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSource, .defaultMode)
            self.powerSource = nil
        }
    }

    func refresh() {
        let next = Self.read()
        guard next != snapshot else { return }
        snapshot = next
        onChange?(next)
    }

    static func read() -> BatterySnapshot {
        var snapshot = BatterySnapshot()
        let powerSource = IOPSGetProvidingPowerSourceType(nil)?.takeRetainedValue() as String?
        snapshot.isOnAC = powerSource == kIOPSACPowerValue

        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return snapshot }

        for source in list {
            guard let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  info[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
            snapshot.hasBattery = true
            snapshot.isCharging = info[kIOPSIsChargingKey] as? Bool ?? false
            if let current = info[kIOPSCurrentCapacityKey] as? Int,
               let maximum = info[kIOPSMaxCapacityKey] as? Int,
               maximum > 0 {
                snapshot.level = Int((Double(current) / Double(maximum) * 100).rounded())
            }
            break
        }
        return snapshot
    }
}
