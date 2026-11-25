import AppKit
import Carbon.HIToolbox
import Observation

/// Records a shortcut for one slot at a time in a window, such as one app's shortcut on Portkey's page in the Prism
/// window.
///
/// The keys come from a local event monitor rather than a focused view: a combination with ⌘ goes to the key
/// equivalents before any view sees it, and the monitor sees it first. Local monitors need no permission.
///
/// The tool decides whether to take a combination: `setShortcut` returns why it refused, or nil once the slot has it.
/// While recording, the tool lets go of its shortcuts through `pauseShortcuts`; otherwise pressing a combination
/// that is already set would run it, and the window would never see the key.
@MainActor
@Observable
public final class ShortcutRecorder<Slot: Hashable, Refusal: Equatable> {
    public struct Notice: Equatable {
        public let slot: Slot
        public let shortcut: Shortcut
        public let refusal: Refusal
    }

    public private(set) var recordingSlot: Slot?
    /// Why the last combination was refused. It stays until the next recording starts or one succeeds.
    public private(set) var notice: Notice?
    @ObservationIgnored private let setShortcut: @MainActor (Shortcut?, Slot) -> Refusal?
    @ObservationIgnored private let pauseShortcuts: @MainActor (Bool) -> Void
    @ObservationIgnored private var monitors: [Any] = []
    @ObservationIgnored private var windowObservers: [NSObjectProtocol] = []

    public init(
        setShortcut: @escaping @MainActor (Shortcut?, Slot) -> Refusal?,
        pauseShortcuts: @escaping @MainActor (Bool) -> Void
    ) {
        self.setShortcut = setShortcut
        self.pauseShortcuts = pauseShortcuts
    }

    public func start(for slot: Slot) {
        stop()
        notice = nil
        recordingSlot = slot
        pauseShortcuts(true)
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
        // The window the person clicked to start: leaving it or closing it ends the recording.
        if let window = NSApp.keyWindow {
            let center = NotificationCenter.default
            windowObservers = [NSWindow.didResignKeyNotification, NSWindow.willCloseNotification].map { name in
                center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.stop() }
                }
            }
        }
    }

    public func stop() {
        guard recordingSlot != nil else { return }
        recordingSlot = nil
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors = []
        for observer in windowObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        windowObservers = []
        pauseShortcuts(false)
    }

    public func clear(_ slot: Slot) {
        stop()
        if notice?.slot == slot { notice = nil }
        _ = setShortcut(nil, slot)
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        guard let slot = recordingSlot else { return false }
        guard !event.isARepeat else { return true }
        let modifiers = event.modifierFlags.intersection([.control, .option, .shift, .command])
        if modifiers.isEmpty {
            switch Int(event.keyCode) {
            case kVK_Escape:
                stop()
                return true
            case kVK_Delete, kVK_ForwardDelete:
                clear(slot)
                return true
            default:
                break
            }
        }
        let shortcut = Shortcut(event: event)
        if let refusal = setShortcut(shortcut, slot) {
            notice = Notice(slot: slot, shortcut: shortcut, refusal: refusal)
        } else {
            notice = nil
            stop()
        }
        return true
    }
}
