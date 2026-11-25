import Carbon.HIToolbox
import os

// RegisterEventHotKey needs no Accessibility permission, unlike a global NSEvent monitor.
@MainActor
public enum GlobalHotKey {
    public struct Registration: Hashable, Sendable {
        fileprivate let id: UInt32
    }

    public struct HotKeyError: Error, Equatable {
        public let status: OSStatus
    }

    private struct Entry {
        let ref: EventHotKeyRef
        let action: @MainActor () -> Void
    }

    fileprivate nonisolated static let signature = OSType(0x4C4D_4158)
    private static var entries: [UInt32: Entry] = [:]
    private static var nextID: UInt32 = 1
    private static var handlerInstalled = false
    private static let logger = Logger(subsystem: "io.github.zchan0.prism", category: "GlobalHotKey")

    /// `keyCode` is a virtual key code such as `kVK_ANSI_1`; `modifiers` is a Carbon mask such as `cmdKey | optionKey`.
    public static func register(
        keyCode: UInt32,
        modifiers: UInt32,
        action: @escaping @MainActor () -> Void
    ) -> Result<Registration, HotKeyError> {
        if !handlerInstalled {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let status = InstallEventHandler(GetApplicationEventTarget(), hotKeyPressed, 1, &eventType, nil, nil)
            guard status == noErr else {
                logger.error("InstallEventHandler failed: \(status)")
                return .failure(HotKeyError(status: status))
            }
            handlerInstalled = true
        }

        let id = nextID
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            EventHotKeyID(signature: signature, id: id),
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else {
            logger.error("RegisterEventHotKey failed: \(status)")
            return .failure(HotKeyError(status: status))
        }
        nextID += 1
        entries[id] = Entry(ref: ref, action: action)
        return .success(Registration(id: id))
    }

    public static func unregister(_ registration: Registration) {
        guard let entry = entries.removeValue(forKey: registration.id) else { return }
        let status = UnregisterEventHotKey(entry.ref)
        if status != noErr {
            logger.error("UnregisterEventHotKey failed: \(status)")
        }
    }

    /// Whether macOS takes the combination now; it says no when this process holds it already.
    public static func canRegister(_ shortcut: Shortcut) -> Bool {
        switch register(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers, action: {}) {
        case .success(let registration):
            unregister(registration)
            return true
        case .failure:
            return false
        }
    }

    fileprivate static func fire(_ id: UInt32) -> Bool {
        guard let action = entries[id]?.action else { return false }
        action()
        return true
    }
}

private func hotKeyPressed(_ handler: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr, hotKeyID.signature == GlobalHotKey.signature else { return OSStatus(eventNotHandledErr) }
    let handled = MainActor.assumeIsolated { GlobalHotKey.fire(hotKeyID.id) }
    return handled ? noErr : OSStatus(eventNotHandledErr)
}
