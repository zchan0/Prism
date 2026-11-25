import Foundation
import PrismKit
import Testing
@testable import LumosTool

/// The session handed from the Prism that relaunches for an update to the one it opens. Every lid flag here is a
/// scratch file: the real one would wake the installed helper.
@MainActor
struct LumosHandoffTests {
    // MARK: Before the relaunch

    @Test func withoutASessionThereIsNothingToHandOver() {
        let setup = Setup()
        defer { setup.cleanUp() }
        #expect(setup.model.prepareForRelaunch() == nil)
        #expect(setup.defaults.object(forKey: SessionHandoff.key) == nil)
        #expect(!setup.model.isHandingOff)
    }

    @Test func aRunningSessionIsSavedAndHeld() {
        let setup = Setup()
        defer { setup.cleanUp() }
        setup.model.preferences.keepsDisplayAwake = true
        setup.model.start(length: .thirtyMinutes)
        setup.clock.now += 5 * 60

        let hold = setup.model.prepareForRelaunch()
        #expect(hold == RelaunchHold(keepsSystemAwake: true, keepsDisplayAwake: true, heldFiles: []))
        let record = SessionHandoff.take(from: setup.defaults)
        #expect(record?.endsAt == setup.model.engine.endsAt)
        #expect(record?.startedAt == setup.model.engine.startedAt)
        #expect(record?.writtenAt == setup.clock.now)
        #expect(record?.length == .thirtyMinutes)
        #expect(record?.keepsLidOverride == false)
    }

    @Test func theLidFlagIsHeldWhileThisAppKeepsTheLidSettingOn() throws {
        let setup = Setup()
        defer { setup.cleanUp() }
        try setup.createFlag()
        #expect(setup.model.lid.resumeHoldingFlag())
        setup.model.start(length: .oneHour)

        let hold = setup.model.prepareForRelaunch()
        #expect(hold?.heldFiles == [setup.flagPath])
        #expect(SessionHandoff.take(from: setup.defaults)?.keepsLidOverride == true)
        #expect(LidControl(runner: FakeRunner(), defaults: MemoryDefaults()).flagPath == LidControl.flagPath)
    }

    @Test func quittingAfterTheHandoffLeavesTheSessionAlone() async throws {
        let setup = Setup()
        defer { setup.cleanUp() }
        try setup.createFlag()
        #expect(setup.model.lid.resumeHoldingFlag())
        setup.runner.sleepDisabled = true
        await setup.model.lid.refresh()
        // After starting: a start with the lid setting on would turn it on again itself.
        setup.model.start(length: .thirtyMinutes)
        setup.model.preferences.keepsAwakeWithLidClosed = true
        _ = setup.model.prepareForRelaunch()
        let commands = setup.runner.commands

        setup.model.tearDown()
        await setup.settle()
        #expect(FileManager.default.fileExists(atPath: setup.flagPath))
        #expect(setup.model.preferences.keepsAwakeWithLidClosed)
        #expect(setup.notifier.posts.isEmpty)
        #expect(setup.runner.commands == commands)
    }

    @Test func quittingWithoutAHandoffStillEndsTheSession() async throws {
        let setup = Setup()
        defer { setup.cleanUp() }
        try setup.createFlag()
        #expect(setup.model.lid.resumeHoldingFlag())
        setup.model.start(length: .thirtyMinutes)
        setup.model.preferences.keepsAwakeWithLidClosed = true

        setup.model.tearDown()
        await setup.settle()
        #expect(!FileManager.default.fileExists(atPath: setup.flagPath))
        #expect(!setup.model.preferences.keepsAwakeWithLidClosed)
        #expect(!setup.model.engine.isAwake)
    }

    @Test func aCancelledRelaunchDropsTheRecord() async throws {
        let setup = Setup()
        defer { setup.cleanUp() }
        try setup.createFlag()
        #expect(setup.model.lid.resumeHoldingFlag())
        setup.model.start(length: .thirtyMinutes)
        _ = setup.model.prepareForRelaunch()

        setup.model.relaunchCancelled()
        #expect(setup.defaults.object(forKey: SessionHandoff.key) == nil)
        #expect(!setup.model.isHandingOff)
        setup.model.tearDown()
        await setup.settle()
        #expect(!FileManager.default.fileExists(atPath: setup.flagPath))
    }

    // MARK: After the relaunch

    @Test func aFreshRecordResumesTheSession() {
        let setup = Setup()
        defer { setup.cleanUp() }
        let now = setup.clock.now
        let record = SessionHandoff(
            writtenAt: now - 10,
            startedAt: now - 10 * 60,
            endsAt: now + 20 * 60,
            length: .thirtyMinutes,
            keepsLidOverride: false
        )
        record.save(to: setup.defaults)

        setup.model.launch()
        let engine = setup.model.engine
        #expect(engine.isAwake)
        #expect(engine.remaining() == TimeInterval(20 * 60))
        #expect(engine.startedAt == record.startedAt)
        #expect(engine.length == .thirtyMinutes)
        #expect(setup.assertion.isHolding)
        #expect(setup.defaults.object(forKey: SessionHandoff.key) == nil)
        #expect(setup.notifier.posts.isEmpty)
    }

    @Test func aRecordOlderThanAMinuteIsIgnored() async throws {
        let setup = Setup()
        defer { setup.cleanUp() }
        try setup.createFlag()
        setup.model.preferences.keepsAwakeWithLidClosed = true
        let now = setup.clock.now
        SessionHandoff(writtenAt: now - 61, startedAt: now - 600, endsAt: now + 600, length: .thirtyMinutes, keepsLidOverride: true)
            .save(to: setup.defaults)

        setup.model.launch()
        await setup.model.launchWork?.value
        #expect(!setup.model.engine.isAwake)
        #expect(!setup.model.preferences.keepsAwakeWithLidClosed)
        #expect(!FileManager.default.fileExists(atPath: setup.flagPath))
        #expect(setup.defaults.object(forKey: SessionHandoff.key) == nil)
    }

    @Test func aRecordOfASessionThatHasEndedIsIgnored() async {
        let setup = Setup()
        defer { setup.cleanUp() }
        let now = setup.clock.now
        SessionHandoff(writtenAt: now - 10, startedAt: now - 1800, endsAt: now - 1, length: .thirtyMinutes, keepsLidOverride: false)
            .save(to: setup.defaults)

        setup.model.launch()
        await setup.model.launchWork?.value
        #expect(!setup.model.engine.isAwake)
        #expect(setup.defaults.object(forKey: SessionHandoff.key) == nil)
    }

    @Test func aSessionUntilStoppedResumesUntilStopped() {
        let setup = Setup()
        defer { setup.cleanUp() }
        let now = setup.clock.now
        SessionHandoff(writtenAt: now - 5, startedAt: now - 3600, endsAt: nil, length: .forever, keepsLidOverride: false)
            .save(to: setup.defaults)

        setup.model.launch()
        #expect(setup.model.engine.isAwake)
        #expect(setup.model.engine.remaining() == nil)
        #expect(setup.model.engine.length == .forever)
    }

    @Test func theLidSettingCarriesOverWithItsFlag() async throws {
        let setup = Setup()
        defer { setup.cleanUp() }
        try setup.createFlag()
        setup.runner.sleepDisabled = true
        setup.model.preferences.keepsAwakeWithLidClosed = true
        let now = setup.clock.now
        SessionHandoff(writtenAt: now - 3, startedAt: now - 60, endsAt: now + 600, length: .thirtyMinutes, keepsLidOverride: true)
            .save(to: setup.defaults)

        setup.model.launch()
        await setup.model.launchWork?.value
        #expect(setup.model.engine.isAwake)
        #expect(setup.model.lid.holdsFlag)
        #expect(FileManager.default.fileExists(atPath: setup.flagPath))
        #expect(setup.model.preferences.keepsAwakeWithLidClosed)
        #expect(setup.model.lid.isSystemSleepDisabled)
    }

    @Test func withoutARecordLaunchingCleansUpAsBefore() async throws {
        let setup = Setup()
        defer { setup.cleanUp() }
        try setup.createFlag()
        setup.model.preferences.keepsAwakeWithLidClosed = true

        setup.model.launch()
        #expect(!setup.model.preferences.keepsAwakeWithLidClosed)
        await setup.model.launchWork?.value
        #expect(!setup.model.engine.isAwake)
        #expect(!FileManager.default.fileExists(atPath: setup.flagPath))
        #expect(setup.notifier.posts.isEmpty)
    }
}

@MainActor
private final class Setup {
    let defaults = MemoryDefaults()
    let clock = Clock()
    let assertion = FakeAssertion()
    let runner = FakeRunner()
    let notifier = FakeNotifier()
    let directory: URL
    let model: AppModel

    var flagPath: String { model.lid.flagPath }

    init() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("LumosHandoffTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let clock = clock
        let preferences = Preferences(defaults: defaults)
        // A Mac on a low battery would otherwise stop a session in the middle of a test.
        preferences.lowBatteryThreshold = .off
        model = AppModel(
            preferences: preferences,
            engine: SessionEngine(assertion: assertion, ticker: FakeTicker(), clock: { clock.now }),
            lid: LidControl(runner: runner, defaults: defaults, flagPath: directory.appendingPathComponent("session").path),
            notifier: notifier,
            defaults: defaults,
            clock: { clock.now }
        )
    }

    func createFlag() throws {
        try Data().write(to: URL(fileURLWithPath: flagPath))
    }

    /// Lets the tasks a stop starts run.
    func settle() async {
        for _ in 0..<20 {
            await Task.yield()
        }
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: directory)
    }
}

@MainActor
private final class Clock {
    var now = Date(timeIntervalSince1970: 1_800_000_000)
}

@MainActor
private final class FakeAssertion: SleepAsserting {
    var isHolding = false

    func acquire(keepsDisplayAwake: Bool) throws {
        isHolding = true
    }

    func release() {
        isHolding = false
    }
}

@MainActor
private final class FakeTicker: Ticking {
    func start(every interval: TimeInterval, _ action: @escaping @MainActor () -> Void) {}
    func stop() {}
}

/// Answers pmset like the real one, without touching the system's sleep setting.
@MainActor
private final class FakeRunner: CommandRunning {
    var sleepDisabled = false
    private(set) var commands: [String] = []

    func run(_ executable: String, _ arguments: [String]) async -> CommandResult {
        commands.append(([executable] + arguments).joined(separator: " "))
        return CommandResult(status: 0, output: " SleepDisabled\t\(sleepDisabled ? 1 : 0)\n", error: "")
    }
}

@MainActor
private final class FakeNotifier: Notifying {
    private(set) var posts: [String] = []

    func requestAuthorization() {}

    func postTimerEnded() {
        posts.append("timer")
    }

    func postBatteryStopped(level: Int) {
        posts.append("battery \(level)")
    }
}
