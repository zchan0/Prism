import Foundation
import Observation

/// One place that owns the session and its side effects: the lid setting, the pet's food, notifications.
@MainActor
@Observable
final class AppModel {
    let preferences: Preferences
    let engine: SessionEngine
    let battery: BatteryMonitor
    let lid: LidControl
    let awakeLog: AwakeLog
    let loginItem = LoginItem()

    private(set) var lastError: String?
    private(set) var lastStop: StopReason?
    /// Mirrors the pet window, so the pet's animation only runs while it is on screen.
    var petVisible = false

    var onStopCompleted: (@MainActor (StopReason) -> Void)?

    @ObservationIgnored private let notifier: Notifier
    /// Awake time already folded into the log for the running session, so a stop adds only the remainder.
    @ObservationIgnored private var flushed: TimeInterval = 0

    init(
        preferences: Preferences = Preferences(),
        engine: SessionEngine = SessionEngine(),
        battery: BatteryMonitor = BatteryMonitor(),
        lid: LidControl = LidControl(),
        awakeLog: AwakeLog = AwakeLog(),
        notifier: Notifier = Notifier()
    ) {
        self.preferences = preferences
        self.engine = engine
        self.battery = battery
        self.lid = lid
        self.awakeLog = awakeLog
        self.notifier = notifier
        engine.onEvent = { [weak self] event in self?.handle(event) }
        battery.onChange = { [weak self] snapshot in self?.batteryChanged(snapshot) }
    }

    var isAwake: Bool { engine.isAwake }
    var remaining: TimeInterval? { engine.remaining() }
    var sunHours: Double { awakeLog.todayIncluding(engine.elapsed - flushed) / 3600 }

    var menuBarState: MenuBarState {
        let mode: MenuBarState.Mode
        if !engine.isAwake {
            mode = .asleep
        } else if let remaining {
            mode = .counting(remaining: Int(remaining.rounded(.up)))
        } else {
            mode = .forever
        }
        return MenuBarState(mode: mode, showsTime: preferences.showsTimeInMenuBar, holdsDisplay: engine.holdsDisplay)
    }

    func launch() {
        battery.start()
        notifier.requestAuthorization()
        Task {
            await lid.refresh()
            lid.adoptSystemState()
            // The lid setting is global and survives a crash, so a leftover from a previous run is undone here.
            await lid.repairIfNeeded()
        }
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
        flushed = 0
        guard engine.start(length: length, keepsDisplayAwake: preferences.keepsDisplayAwake) else {
            lastError = Strings.cannotStart
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

    func resetPet() {
        awakeLog.reset()
    }

    /// Called about once a second while the UI is visible; the log is folded in whole minutes.
    func uiTick() {
        guard engine.isAwake else { return }
        engine.refreshNow()
        flushElapsed()
    }

    /// Called from the engine's own one-second timer when no window is open, so the log keeps counting.
    func backgroundTick() {
        guard engine.isAwake else { return }
        flushElapsed()
    }

    private func enableLidControl() async {
        let succeeded = await lid.setEnabled(true)
        preferences.keepsAwakeWithLidClosed = succeeded
        if !succeeded {
            lastError = lid.errorMessage
        }
    }

    private func flushElapsed() {
        let elapsed = engine.elapsed
        guard elapsed - flushed >= 60 else { return }
        awakeLog.add(elapsed - flushed)
        flushed = elapsed
    }

    private func handle(_ event: SessionEvent) {
        switch event {
        case .started:
            lastStop = nil
            lastError = nil
        case .stopped(let reason, let duration):
            lastStop = reason
            // The last partial minute before the stop still counts toward the pet's day.
            if duration > flushed {
                awakeLog.add(duration - flushed)
            }
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
            flushed = 0
            awakeLog.pet()
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
