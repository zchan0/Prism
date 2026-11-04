import Foundation

@MainActor
public protocol Ticking: AnyObject {
    func start(every interval: TimeInterval, _ action: @escaping @MainActor () -> Void)
    func stop()
}

@MainActor
public final class Ticker: Ticking {
    private var timer: Timer?

    public init() {}

    public func start(every interval: TimeInterval, _ action: @escaping @MainActor () -> Void) {
        stop()
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            MainActor.assumeIsolated { action() }
        }
        timer.tolerance = interval / 10
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }
}
