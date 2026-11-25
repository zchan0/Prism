import Foundation
import Observation
import os
import PrismKit

/// One place that owns the session and its side effects: the lid setting and notifications.
@MainActor
@Observable
final class AppModel {
    let preferences: Preferences
    let engine: SessionEngine
    let battery: BatteryMonitor
    let lid: LidControl

    private(set) var lastError: String?
    private(set) var lastStop: StopReason?
    #if DEBUG
    /// For screenshots: the controls show the battery note and an error, whatever the power source.
    var showsNotesForDebug = false
    /// For screenshots: the lid flag, and in a packaged build the settings, are shared with the installed Prism,
    /// whose lid session the clean-up at launch would end.
    var leavesLidAloneForDebug = false
    #endif

    var onStopCompleted: (@MainActor (StopReason) -> Void)?

    /// Set by `prepareForRelaunch()`: the session goes on in the next process, so quitting leaves it alone.
    @ObservationIgnored private(set) var isHandingOff = false
    /// The lid clean-up `launch()` starts, for a test to wait on.
    @ObservationIgnored private(set) var launchWork: Task<Void, Never>?

    @ObservationIgnored private let notifier: Notifying
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let clock: @MainActor () -> Date

    private static let logger = Logger(subsystem: "io.github.zchan0.prism", category: "lumos")

    init(
        preferences: Preferences = Preferences(),
        engine: SessionEngine = SessionEngine(),
        battery: BatteryMonitor = BatteryMonitor(),
        lid: LidControl = LidControl(),
        notifier: Notifying = Notifier(),
        defaults: UserDefaults = .standard,
        clock: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.preferences = preferences
        self.engine = engine
        self.battery = battery
        self.lid = lid
        self.notifier = notifier
        self.defaults = defaults
        self.clock = clock
        engine.onEvent = { [weak self] event in self?.handle(event) }
        battery.onChange = { [weak self] snapshot in self?.batteryChanged(snapshot) }
    }

    var isAwake: Bool { engine.isAwake }
    var remaining: TimeInterval? { engine.remaining() }

    var menuBarState: MenuBarState {
        let mode: MenuBarState.Mode
        if !engine.isAwake {
            mode = .asleep
        } else if let remaining {
            mode = .counting(remaining: Int(remaining.rounded(.up)))
        } else {
            mode = .forever
        }
        return MenuBarState(mode: mode, showsTime: preferences.showsTimeInMenuBar)
    }

    func launch() {
        battery.start()
        notifier.requestAuthorization()
        #if DEBUG
        if leavesLidAloneForDebug {
            Task { await lid.refresh() }
            return
        }
        #endif
        if resumeHandedOffSession() { return }
        // Only a relaunch for an update carries a session over, so a lid override left over from the last run has
        // nothing to cover.
        preferences.keepsAwakeWithLidClosed = false
        launchWork = Task {
            await lid.refresh()
            lid.adoptSystemState()
            // The lid setting is global and survives a crash, so a leftover from a previous run is undone here.
            await lid.repairIfNeeded()
        }
    }

    /// Saves the session for the Prism an update opens, and returns what has to be held for it in between.
    func prepareForRelaunch() -> RelaunchHold? {
        guard engine.isAwake, let startedAt = engine.startedAt else { return nil }
        let keepsLidOverride = lid.holdsFlag
        SessionHandoff(
            writtenAt: clock(),
            startedAt: startedAt,
            endsAt: engine.endsAt,
            length: engine.length,
            keepsLidOverride: keepsLidOverride
        ).save(to: defaults)
        isHandingOff = true
        return RelaunchHold(
            keepsSystemAwake: true,
            keepsDisplayAwake: engine.holdsDisplay,
            heldFiles: keepsLidOverride ? [lid.flagPath] : []
        )
    }

    func relaunchCancelled() {
        guard isHandingOff else { return }
        isHandingOff = false
        SessionHandoff.discard(in: defaults)
    }

    /// When the tool stops, which is also when Prism quits. A session handed to the next process is left running:
    /// its power assertion goes away with this process, and its lid flag stays for the relaunch to hold.
    func tearDown() {
        guard !isHandingOff else { return }
        stop()
        repairOnQuit()
    }

    func toggle() {
        if engine.isAwake {
            stop()
        } else {
            start(length: preferences.lastLength)
        }
    }

    func start(length: SessionLength) {
        preferences.lastLength = length
        lastError = nil
        guard engine.start(length: length, keepsDisplayAwake: preferences.keepsDisplayAwake) else {
            lastError = LumosStrings.cannotStart
            return
        }
        if preferences.keepsAwakeWithLidClosed {
            Task { await enableLidControl() }
        }
    }

    func stop() {
        guard engine.isAwake else { return }
        engine.stop(.manual)
    }

    /// 30 minutes, 1 hour, 2 hours, or until stopped: re-picking a length while awake only re-times the timer.
    func setLength(_ length: SessionLength) {
        // Picking a length while asleep is the shortest way to start: one click instead of two.
        guard engine.isAwake else {
            start(length: length)
            return
        }
        preferences.lastLength = length
        engine.start(length: length, keepsDisplayAwake: preferences.keepsDisplayAwake)
    }

    func setKeepsDisplayAwake(_ keepsDisplay: Bool) {
        preferences.keepsDisplayAwake = keepsDisplay
        engine.setKeepsDisplayAwake(keepsDisplay)
    }

    func setKeepsAwakeWithLidClosed(_ enabled: Bool) async {
        if enabled {
            await enableLidControl()
        } else {
            preferences.keepsAwakeWithLidClosed = false
            if lid.isSystemSleepDisabled {
                _ = await lid.setEnabled(false)
            }
        }
    }

    func repairOnQuit() {
        lid.repairSynchronously()
    }

    func uiTick() {
        guard engine.isAwake else { return }
        engine.refreshNow()
    }

    /// Picks up the session the previous process handed over, when it relaunched for an update a moment ago.
    private func resumeHandedOffSession() -> Bool {
        let hasRecord = defaults.object(forKey: SessionHandoff.key) != nil
        guard let handoff = SessionHandoff.take(from: defaults) else {
            if hasRecord {
                Self.logger.notice("not resuming the session: the handoff could not be read")
            }
            return false
        }
        let now = clock()
        if let reason = handoff.rejection(at: now) {
            Self.logger.notice("not resuming the session: the handoff was \(reason, privacy: .public)")
            return false
        }
        guard engine.resume(
            startedAt: handoff.startedAt,
            endsAt: handoff.endsAt,
            length: handoff.length,
            keepsDisplayAwake: preferences.keepsDisplayAwake
        ) else {
            Self.logger.notice("not resuming the session: no power assertion")
            return false
        }
        let keepsLid = handoff.keepsLidOverride && lid.resumeHoldingFlag()
        let left = handoff.endsAt.map { "\(Int(max(0, $0.timeIntervalSince(now)).rounded())) s left" } ?? "until stopped"
        Self.logger.notice("resumed the session: \(left, privacy: .public), lid closed kept: \(keepsLid, privacy: .public)")
        if keepsLid {
            preferences.keepsAwakeWithLidClosed = true
            launchWork = Task { await lid.refresh() }
        } else {
            preferences.keepsAwakeWithLidClosed = false
            launchWork = Task {
                await lid.refresh()
                lid.adoptSystemState()
                await lid.repairIfNeeded()
            }
        }
        return true
    }

    private func enableLidControl() async {
        let succeeded = await lid.setEnabled(true)
        preferences.keepsAwakeWithLidClosed = succeeded
        if !succeeded {
            lastError = lid.errorMessage
        }
    }

    private func handle(_ event: SessionEvent) {
        switch event {
        case .started:
            lastStop = nil
            lastError = nil
        case .stopped(let reason, _):
            lastStop = reason
            // The session is over, so the lid override is over too; the switch would otherwise claim a state
            // that nothing is enforcing.
            preferences.keepsAwakeWithLidClosed = false
            Task { [weak self] in
                guard let self, lid.isSystemSleepDisabled else { return }
                _ = await lid.setEnabled(false)
            }
            switch reason {
            case .timerFinished where preferences.notifiesWhenTimerEnds:
                notifier.postTimerEnded()
            case .lowBattery(let level) where preferences.notifiesWhenBatteryLow:
                notifier.postBatteryStopped(level: level)
            default:
                break
            }
            onStopCompleted?(reason)
        }
    }

    private func batteryChanged(_ snapshot: BatterySnapshot) {
        guard engine.isAwake else { return }
        if BatteryPolicy.stopsSession(snapshot, threshold: preferences.lowBatteryThreshold.percent),
           let level = snapshot.level {
            engine.stop(.lowBattery(level: level))
        }
    }
}
