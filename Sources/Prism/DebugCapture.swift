#if DEBUG
import AppKit

@MainActor
enum DebugCapture {
    /// Screenshots a window on screen. SwiftUI's toolbar and glass are window-server effects that cacheDisplay misses.
    static func window(_ window: NSWindow, to path: String) async -> Bool {
        window.orderFrontRegardless()
        try? await Task.sleep(for: .seconds(1.2))
        print("settings window: \(window.frame) content: \(window.contentLayoutRect.size)")
        let capture = Process()
        capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        capture.arguments = ["-x", "-o", "-l", String(window.windowNumber), path]
        do {
            try capture.run()
        } catch {
            print("capture: \(error.localizedDescription)")
            return false
        }
        capture.waitUntilExit()
        return capture.terminationStatus == 0
    }
}
#endif
