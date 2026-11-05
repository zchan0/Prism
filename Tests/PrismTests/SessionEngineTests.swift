import Foundation
import Observation
import Testing
@testable import LumosTool
import PrismKit

struct BatteryPolicyTests {
    @Test func stopsWhenUnpluggedAtTheThreshold() {
        let snapshot = BatterySnapshot(hasBattery: true, level: 20, isCharging: false, isOnAC: false)
        #expect(BatteryPolicy.stopsSession(snapshot, threshold: 20))
    }

    @Test func keepsRunningWhenPluggedInEvenAtTheThreshold() {
        let snapshot = BatterySnapshot(hasBattery: true, level: 5, isCharging: false, isOnAC: true)
        #expect(!BatteryPolicy.stopsSession(snapshot, threshold: 40))
    }

    @Test func chargingCountsAsPluggedIn() {
        let snapshot = BatterySnapshot(hasBattery: true, level: 8, isCharging: true, isOnAC: false)
        #expect(!BatteryPolicy.stopsSession(snapshot, threshold: 20))
    }

    @Test func neverStopsWithoutAThreshold() {
        let snapshot = BatterySnapshot(hasBattery: true, level: 3, isCharging: false, isOnAC: false)
        #expect(!BatteryPolicy.stopsSession(snapshot, threshold: nil))
    }

    @Test func neverStopsADesktop() {
        let snapshot = BatterySnapshot(hasBattery: false, level: nil, isCharging: false, isOnAC: true)
        #expect(!BatteryPolicy.stopsSession(snapshot, threshold: 20))
    }

    @Test func ignoresABatteryThatReportsNoLevel() {
        let snapshot = BatterySnapshot(hasBattery: true, level: nil, isCharging: false, isOnAC: false)
        #expect(!BatteryPolicy.stopsSession(snapshot, threshold: 50))
    }
}

struct SessionLengthTests {
    @Test func foreverHasNoDeadline() {
        #expect(SessionLength.forever.duration == nil)
    }

    @Test func picksCarryMinutes() {
        #expect(SessionLength.thirtyMinutes.duration == 1800)
        #expect(SessionLength.oneHour.duration == 3600)
        #expect(SessionLength.twoHours.duration == 7200)
    }
}

@MainActor
struct SessionEngineTests {
    private final class FakeAssertion: SleepAsserting {
        var isHolding = false
        var keepsDisplay = false
        var failNext = false
        private(set) var acquisitions = 0

        func acquire(keepsDisplayAwake: Bool) throws {
            guard !failNext else { throw SleepAssertionFailure(code: -536_870_912) }
            acquisitions += 1
            isHolding = true
            keepsDisplay = keepsDisplayAwake
        }

        func release() {
            isHolding = false
        }
    }

    private final class FakeTicker: Ticking {
        var interval: TimeInterval?
        var action: (@MainActor () -> Void)?

        func start(every interval: TimeInterval, _ action: @escaping @MainActor () -> Void) {
            self.interval = interval
            self.action = action
        }

        func stop() {
            action = nil
        }
    }

    private func makeEngine(now: @escaping @MainActor () -> Date) -> (SessionEngine, FakeAssertion, FakeTicker) {
        let assertion = FakeAssertion()
        let ticker = FakeTicker()
        let engine = SessionEngine(assertion: assertion, ticker: ticker, clock: now)
        return (engine, assertion, ticker)
    }

    /// The controls read only these three, so a session that changes none of them would not redraw them.
    private func observesChange(of engine: SessionEngine, when change: () -> Void) -> Bool {
        final class Flag: @unchecked Sendable { var raised = false }
        let flag = Flag()
        withObservationTracking {
            _ = engine.isAwake
            _ = engine.length
            _ = engine.remaining()
        } onChange: {
            flag.raised = true
        }
        change()
        return flag.raised
    }

    @Test func startingWithTheLengthItAlreadyHadStillRedraws() {
        let (engine, _, _) = makeEngine { Date(timeIntervalSinceReferenceDate: 0) }
        #expect(observesChange(of: engine) { engine.start(length: .forever, keepsDisplayAwake: true) })
    }

    @Test func stoppingAnOpenEndedSessionRedraws() {
        let (engine, _, _) = makeEngine { Date(timeIntervalSinceReferenceDate: 0) }
        engine.start(length: .forever, keepsDisplayAwake: true)
        #expect(observesChange(of: engine) { engine.stop(.manual) })
    }

    @Test func startingHoldsTheAssertionAndTicks() {
        var now = Date(timeIntervalSinceReferenceDate: 0)
        let (engine, assertion, ticker) = makeEngine { now }
        #expect(engine.start(length: .oneHour, keepsDisplayAwake: true))
        #expect(assertion.isHolding)
        #expect(assertion.keepsDisplay)
        #expect(ticker.interval == 1)
        #expect(engine.remaining() == 3600)
        _ = now
    }

    @Test func foreverHasNoRemainingTime() {
        let (engine, _, _) = makeEngine { Date(timeIntervalSinceReferenceDate: 0) }
        engine.start(length: .forever, keepsDisplayAwake: false)
        #expect(engine.remaining() == nil)
    }

    @Test func timerStopsTheSession() {
        var now = Date(timeIntervalSinceReferenceDate: 0)
        let (engine, assertion, _) = makeEngine { now }
        var events: [SessionEvent] = []
        engine.onEvent = { events.append($0) }
        engine.start(length: .thirtyMinutes, keepsDisplayAwake: false)
        now = now.addingTimeInterval(1799)
        engine.tick()
        #expect(engine.isAwake)
        now = now.addingTimeInterval(1)
        engine.tick()
        #expect(!engine.isAwake)
        #expect(!assertion.isHolding)
        #expect(events.contains(.stopped(.timerFinished, duration: 1800)))
    }

    @Test func retimingKeepsTheSameAssertion() {
        var now = Date(timeIntervalSinceReferenceDate: 0)
        let (engine, assertion, _) = makeEngine { now }
        engine.start(length: .forever, keepsDisplayAwake: false)
        now = now.addingTimeInterval(60)
        engine.start(length: .twoHours, keepsDisplayAwake: false)
        #expect(assertion.acquisitions == 1)
        #expect(engine.remaining() == 7200)
    }

    @Test func failureLeavesTheEngineStoppedAndReportsIt() {
        let (engine, assertion, _) = makeEngine { Date(timeIntervalSinceReferenceDate: 0) }
        assertion.failNext = true
        #expect(!engine.start(length: .oneHour, keepsDisplayAwake: false))
        #expect(!engine.isAwake)
        #expect(engine.failure != nil)
    }

    @Test func displayOnlyChangeReacquiresInPlace() {
        let (engine, assertion, _) = makeEngine { Date(timeIntervalSinceReferenceDate: 0) }
        engine.start(length: .oneHour, keepsDisplayAwake: true)
        engine.setKeepsDisplayAwake(false)
        #expect(assertion.isHolding)
        #expect(!assertion.keepsDisplay)
        #expect(engine.isAwake)
    }
}

@MainActor
struct LidControlTests {
    @Test func readsTheSleepDisabledLine() {
        let output = """
        System-wide power settings:
         SleepDisabled             1
        Currently in use:
         sleep                     1
        """
        #expect(LidControl.parseSleepDisabled(output))
    }

    @Test func missingLineMeansEnabled() {
        #expect(!LidControl.parseSleepDisabled("System-wide power settings:\n sleep 1"))
    }

    @Test func installerWritesARootDaemonThatWatchesTheFlag() {
        let script = LidControl.installerScript
        #expect(script.contains("cat > \(LidControl.scriptPath)"))
        #expect(script.contains("cat > \(LidControl.daemonPath)"))
        #expect(script.contains("launchctl bootstrap system"))
        #expect(LidControl.daemonPlist.contains("<string>\(LidControl.flagDirectory)</string>"))
        #expect(LidControl.helperScript.contains("flag=\(LidControl.flagPath)"))
        #expect(LidControl.helperScript.contains("/usr/sbin/lsof -t -- \"$flag\""))
        #expect(LidControl.helperScript.contains("pmset -a disablesleep $want"))
        #expect(!LidControl.helperScript.contains("pgrep"))
    }

    /// The helper's whole test of whether the app is running: does any process hold the flag open.
    @Test func aHeldFlagIsSeenUntilItIsReleased() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: path) }

        var flag = LidControl.holdFile(at: path)
        #expect(flag != nil)
        #expect(try processes(holding: path) == [getpid()])

        flag = nil
        #expect(try processes(holding: path).isEmpty)
    }

    @Test func aHelperFromAnotherBuildIsReplaced() {
        #expect(LidControl.matches(installed: LidControl.helperScript + "\n", expected: LidControl.helperScript))
        #expect(!LidControl.matches(installed: nil, expected: LidControl.helperScript))
        #expect(!LidControl.matches(installed: "#!/bin/zsh\nexit 0", expected: LidControl.helperScript))
    }

    private func processes(holding path: String) throws -> [Int32] {
        let lsof = Process()
        lsof.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        lsof.arguments = ["-t", "--", path]
        let output = Pipe()
        lsof.standardOutput = output
        lsof.standardError = FileHandle.nullDevice
        try lsof.run()
        lsof.waitUntilExit()
        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return text.split(separator: "\n").compactMap { Int32($0) }
    }
}
