import Foundation
import IOKit.pwr_mgt

@MainActor
protocol SleepAsserting: AnyObject {
    var isHolding: Bool { get }
    func acquire(keepsDisplayAwake: Bool) throws
    func release()
}

struct SleepAssertionFailure: Error, Equatable {
    let code: Int32
}

/// Kernel-held power assertions: the Mac stays awake, and the assertion disappears on its own if the app dies.
@MainActor
final class PowerAssertion: SleepAsserting {
    private var systemSleep: IOPMAssertionID?
    private var displaySleep: IOPMAssertionID?

    var isHolding: Bool { systemSleep != nil }

    func acquire(keepsDisplayAwake: Bool) throws {
        release()
        var id: IOPMAssertionID = 0
        let status = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            Self.reason,
            &id
        )
        guard status == kIOReturnSuccess else { throw SleepAssertionFailure(code: status) }
        systemSleep = id
        guard keepsDisplayAwake else { return }

        var displayID: IOPMAssertionID = 0
        let displayStatus = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            Self.reason,
            &displayID
        )
        if displayStatus == kIOReturnSuccess {
            displaySleep = displayID
        }
    }

    func release() {
        if let systemSleep {
            IOPMAssertionRelease(systemSleep)
            self.systemSleep = nil
        }
        if let displaySleep {
            IOPMAssertionRelease(displaySleep)
            self.displaySleep = nil
        }
    }

    // Shown by `pmset -g assertions`, so it stays English rather than following the UI language.
    private static let reason = "LumosMaxima is keeping this Mac awake" as CFString
}
