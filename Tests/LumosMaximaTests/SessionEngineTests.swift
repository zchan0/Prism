import Foundation
import Testing
@testable import LumosMaxima

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

struct SunStageTests {
    @Test func startsAsASpark() {
        #expect(SunStage.stage(for: 0) == .spark)
        #expect(SunStage.stage(for: 0.9) == .spark)
    }

    @Test func crossesEachThresholdExactly() {
        #expect(SunStage.stage(for: 1) == .ember)
        #expect(SunStage.stage(for: 3) == .flare)
        #expect(SunStage.stage(for: 6) == .sol)
        #expect(SunStage.stage(for: 10) == .nova)
        #expect(SunStage.stage(for: 400) == .nova)
    }

    @Test func growsWithTheStage() {
        let scales = SunStage.allCases.map(\.scale)
        #expect(scales == scales.sorted())
    }

    @Test func progressFillsBetweenStages() {
        #expect(SunStage.progress(for: 0) == 0)
        #expect(SunStage.progress(for: 0.5) == 0.5)
        #expect(SunStage.progress(for: 1) == 0)
        #expect(SunStage.progress(for: 2) == 0.5)
        #expect(SunStage.progress(for: 11) == 1)
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

    @Test func installerWritesARootDaemonThatRechecksTheApp() {
        let script = LidControl.installerScript
        #expect(script.contains("/Library/PrivilegedHelperTools/LumosMaximaLid.sh"))
        #expect(script.contains(LidControl.daemonPath))
        #expect(script.contains("launchctl bootstrap system"))
        #expect(script.contains("pmset -a disablesleep 1"))
        #expect(script.contains("pgrep -x LumosMaxima"))
        #expect(script.contains("<key>WatchPaths</key>"))
    }
}
