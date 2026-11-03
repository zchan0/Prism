import Foundation

@MainActor
protocol Ticking: AnyObject {
    func start(every interval: TimeInterval, _ action: @escaping @MainActor () -> Void)
    func stop()
}

@MainActor
final class Ticker: Ticking {
    private var timer: Timer?

    func start(every interval: TimeInterval, _ action: @escaping @MainActor () -> Void) {
        stop()
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            MainActor.assumeIsolated { action() }
        }
        timer.tolerance = interval / 10
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
