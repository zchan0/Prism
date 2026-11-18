import AppKit
import Carbon.HIToolbox
import Observation

/// Records a shortcut for one app at a time in the Portkey window.
///
/// The keys come from a local event monitor rather than a focused view: a combination with ⌘ goes to the key
/// equivalents before any view sees it, and the monitor sees it first. Local monitors need no permission.
@MainActor
@Observable
final class ShortcutRecorder {
    struct Notice: Equatable {
        let appID: UUID
        let shortcut: Shortcut
        let refusal: ShortcutRefusal
    }

    private(set) var recordingAppID: UUID?
    /// Why the last combination was refused. It stays until the next recording starts or one succeeds.
    private(set) var notice: Notice?
    @ObservationIgnored weak var window: NSWindow?
    @ObservationIgnored private let tool: PortkeyTool
    @ObservationIgnored private var monitors: [Any] = []
    @ObservationIgnored private var windowObservers: [NSObjectProtocol] = []

    init(tool: PortkeyTool) {
        self.tool = tool
    }

    func start(for id: UUID) {
        stop()
        notice = nil
        recordingAppID = id
        tool.setShortcutsPaused(true)
        monitors = [
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                let consumed = MainActor.assumeIsolated { self?.handleKey(event) ?? false }
                return consumed ? nil : event
            },
            // A click anywhere ends the recording; the click still goes where it was aimed.
            NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
                MainActor.assumeIsolated { self?.stop() }
                return event
            },
        ].compactMap { $0 }
        if let window {
            let center = NotificationCenter.default
            windowObservers = [NSWindow.didResignKeyNotification, NSWindow.willCloseNotification].map { name in
                center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.stop() }
                }
            }
        }
    }

    func stop() {
        guard recordingAppID != nil else { return }
        recordingAppID = nil
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors = []
        for observer in windowObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        windowObservers = []
        tool.setShortcutsPaused(false)
    }

    func clear(_ id: UUID) {
        stop()
        if notice?.appID == id { notice = nil }
        tool.setShortcut(nil, for: id)
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        guard let id = recordingAppID else { return false }
        guard !event.isARepeat else { return true }
        let modifiers = event.modifierFlags.intersection([.control, .option, .shift, .command])
        if modifiers.isEmpty {
            switch Int(event.keyCode) {
            case kVK_Escape:
                stop()
                return true
            case kVK_Delete, kVK_ForwardDelete:
                clear(id)
                return true
            default:
                break
            }
        }
        let shortcut = Shortcut(event: event)
        if let refusal = tool.setShortcut(shortcut, for: id) {
            notice = Notice(appID: id, shortcut: shortcut, refusal: refusal)
        } else {
            notice = nil
            stop()
        }
        return true
    }
}
