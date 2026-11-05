import Carbon.HIToolbox
import os

// RegisterEventHotKey needs no Accessibility permission, unlike a global NSEvent monitor.
@MainActor
public enum GlobalHotKey {
    public static let keyName = "⌃⌥⌘L"

    private static var action: (@MainActor () -> Void)?
    private static var hotKeyRef: EventHotKeyRef?
    private static let logger = Logger(subsystem: "io.github.zchan0.prism", category: "GlobalHotKey")

    @discardableResult
    public static func registerToggle(_ action: @escaping @MainActor () -> Void) -> OSStatus {
        self.action = action
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        var status = InstallEventHandler(GetApplicationEventTarget(), hotKeyPressed, 1, &eventType, nil, nil)
        guard status == noErr else {
            logger.error("InstallEventHandler failed: \(status)")
            return status
        }
        let id = EventHotKeyID(signature: OSType(0x4C4D_4158), id: 1)
        status = RegisterEventHotKey(
            UInt32(kVK_ANSI_L),
            UInt32(controlKey | optionKey | cmdKey),
            id,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            logger.error("RegisterEventHotKey failed: \(status)")
        }
        return status
    }

    fileprivate static func fire() {
        action?()
    }
}

private func hotKeyPressed(_ handler: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    MainActor.assumeIsolated { GlobalHotKey.fire() }
    return noErr
}
