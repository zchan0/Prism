import Foundation
import Observation
import PrismKit

enum SessionEvent: Equatable, Sendable {
    case started(SessionLength)
    case stopped(StopReason, duration: TimeInterval)
}

enum StopReason: Equatable, Sendable {
    case manual
    case timerFinished
    case lowBattery(level: Int)
    case failed(code: Int32)

    var wasAutomatic: Bool {
        switch self {
        case .timerFinished, .lowBattery, .failed: true
        case .manual: false
        }
    }

    var endsTheLidOverride: Bool {
        switch self {
        case .timerFinished, .lowBattery, .failed: true
        case .manual: false
        }
    }
}

/// Holds the power assertion for one stretch of "awake time" and owns the countdown.
@MainActor
@Observable
final class SessionEngine {
    private(set) var startedAt: Date?
    private(set) var endsAt: Date?
    private(set) var length: SessionLength = .forever
    private(set) var now: Date
    private(set) var failure: SleepAssertionFailure?
    private(set) var holdsDisplay = false
    /// Stored rather than read from the assertion, so SwiftUI sees an open-ended session start and stop.
    private(set) var isAwake = false

    var onEvent: (@MainActor (SessionEvent) -> Void)?

    @ObservationIgnored private let assertion: SleepAsserting
    @ObservationIgnored private let ticker: Ticking
    @ObservationIgnored private let clock: @MainActor () -> Date

    init(
        assertion: SleepAsserting = PowerAssertion(),
        ticker: Ticking = Ticker(),
        clock: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.assertion = assertion
        self.ticker = ticker
        self.clock = clock
        now = clock()
    }

    var isHoldingDescription: String { "assertion held: \(isAwake)" }
    var elapsed: TimeInterval { startedAt.map { now.timeIntervalSince($0) } ?? 0 }

    func remaining(at date: Date? = nil) -> TimeInterval? {
        guard let endsAt else { return nil }
        return max(0, endsAt.timeIntervalSince(date ?? now))
    }

    /// Starts, or re-times a running session without dropping the assertion.
    @discardableResult
    func start(length: SessionLength, keepsDisplayAwake: Bool) -> Bool {
        let startedNow = clock()
        now = startedNow
        if isAwake {
            // Re-timing keeps the assertion it already holds; only a changed screen option needs a new one.
            self.length = length
            endsAt = length.duration.map { startedNow.addingTimeInterval($0) }
            if keepsDisplayAwake != holdsDisplay {
                holdsDisplay = keepsDisplayAwake
                refreshDisplayAssertion()
            }
            onEvent?(.started(length))
            return true
        }

        do {
            try assertion.acquire(keepsDisplayAwake: keepsDisplayAwake)
        } catch let failure as SleepAssertionFailure {
            self.failure = failure
            return false
        } catch {
            self.failure = SleepAssertionFailure(code: -1)
            return false
        }

        failure = nil
        isAwake = assertion.isHolding
        startedAt = startedNow
        self.length = length
        endsAt = length.duration.map { startedNow.addingTimeInterval($0) }
        holdsDisplay = keepsDisplayAwake
        ticker.start(every: 1) { [weak self] in self?.tick() }
        onEvent?(.started(length))
        return true
    }

    /// Picks up a session the previous process started, after a relaunch for an update: the same start, end and
    /// length. No event, so nothing is announced and no length is remembered as a new pick.
    @discardableResult
    func resume(startedAt: Date, endsAt: Date?, length: SessionLength, keepsDisplayAwake: Bool) -> Bool {
        guard !isAwake else { return false }
        do {
            try assertion.acquire(keepsDisplayAwake: keepsDisplayAwake)
        } catch let failure as SleepAssertionFailure {
            self.failure = failure
            return false
        } catch {
            failure = SleepAssertionFailure(code: -1)
            return false
        }
        failure = nil
        isAwake = assertion.isHolding
        now = clock()
        self.startedAt = startedAt
        self.endsAt = endsAt
        self.length = length
        holdsDisplay = keepsDisplayAwake
        ticker.start(every: 1) { [weak self] in self?.tick() }
        return true
    }

    #if DEBUG
    /// A short countdown for exercising the timer path; release builds only ever use SessionLength.
    func startForDebug(seconds: TimeInterval, keepsDisplayAwake: Bool) {
        start(length: .forever, keepsDisplayAwake: keepsDisplayAwake)
        endsAt = now.addingTimeInterval(seconds)
    }
    #endif

    func stop(_ reason: StopReason) {
        guard isAwake else { return }
        let duration = now.timeIntervalSince(startedAt ?? now)
        assertion.release()
        isAwake = assertion.isHolding
        ticker.stop()
        startedAt = nil
        endsAt = nil
        failure = nil
        onEvent?(.stopped(reason, duration: duration))
    }

    /// A power assertion covers both display and system sleep in one shape, so changing the display option re-acquires it.
    func setKeepsDisplayAwake(_ keepsDisplayAwake: Bool) {
        guard isAwake, keepsDisplayAwake != holdsDisplay else { return }
        holdsDisplay = keepsDisplayAwake
        refreshDisplayAssertion()
    }

    func tick() {
        now = clock()
        if let endsAt, now >= endsAt {
            stop(.timerFinished)
        }
    }

    func refreshNow() {
        now = clock()
    }

    private func refreshDisplayAssertion() {
        do {
            try assertion.acquire(keepsDisplayAwake: holdsDisplay)
            failure = nil
        } catch let failure as SleepAssertionFailure {
            self.failure = failure
        } catch {
            failure = SleepAssertionFailure(code: -1)
        }
        isAwake = assertion.isHolding
    }
}
