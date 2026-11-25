import AppKit
import Carbon.HIToolbox

/// A key with its modifiers, the way `RegisterEventHotKey` takes them. Stored as JSON, so renaming a property loses
/// the person's shortcuts.
///
/// Two shortcuts are the same when their key code and modifiers are: the key name only says what the key typed on the
/// layout it was recorded with.
public struct Shortcut: Codable, Hashable, Sendable {
    public let keyCode: UInt32
    /// A Carbon mask of `controlKey`, `optionKey`, `shiftKey` and `cmdKey`.
    public let modifiers: UInt32
    public let keyName: String

    public static let modifierMask = UInt32(controlKey | optionKey | shiftKey | cmdKey)

    public init(keyCode: UInt32, modifiers: UInt32, keyName: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers & Self.modifierMask
        self.keyName = keyName
    }

    /// One symbol for each modifier, in the order macOS writes them, then the key: ⌥, ⇧, C.
    public var keys: [String] {
        let symbols: [(mask: Int, symbol: String)] = [(controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘")]
        return symbols.filter { modifiers & UInt32($0.mask) != 0 }.map(\.symbol) + [keyName]
    }

    /// Modifiers in the order macOS writes them, such as ⌥⇧C.
    public var text: String { keys.joined() }

    /// ⇧ alone types capitals, and no modifier at all types plain text.
    public var hasRequiredModifier: Bool {
        modifiers & UInt32(controlKey | optionKey | cmdKey) != 0
    }

    public static func == (lhs: Shortcut, rhs: Shortcut) -> Bool {
        lhs.keyCode == rhs.keyCode && lhs.modifiers == rhs.modifiers
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(keyCode)
        hasher.combine(modifiers)
    }
}

public extension Shortcut {
    init(event: NSEvent) {
        let flags = event.modifierFlags
        var modifiers: UInt32 = 0
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        // Without modifiers applied, so ⌥⇧1 is named 1 rather than the ⁄ it types.
        let characters = event.characters(byApplyingModifiers: [])
        self.init(
            keyCode: UInt32(event.keyCode),
            modifiers: modifiers,
            keyName: Self.keyName(keyCode: Int(event.keyCode), characters: characters)
        )
    }

    static func keyName(keyCode: Int, characters: String?) -> String {
        if let name = specialKeyNames[keyCode] { return name }
        let text = (characters ?? "").trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
        return text.isEmpty ? "#\(keyCode)" : text.uppercased()
    }

    /// The keys that type nothing visible, named the way macOS menus name them.
    private static let specialKeyNames: [Int: String] = {
        var names: [Int: String] = [
            kVK_Space: "Space",
            kVK_Return: "↩",
            kVK_ANSI_KeypadEnter: "⌤",
            kVK_Tab: "⇥",
            kVK_Delete: "⌫",
            kVK_ForwardDelete: "⌦",
            kVK_Escape: "⎋",
            kVK_ANSI_KeypadClear: "⌧",
            kVK_LeftArrow: "←",
            kVK_RightArrow: "→",
            kVK_UpArrow: "↑",
            kVK_DownArrow: "↓",
            kVK_Home: "↖",
            kVK_End: "↘",
            kVK_PageUp: "⇞",
            kVK_PageDown: "⇟",
            kVK_Help: "Help",
        ]
        let functionKeys = [
            kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
            kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
        ]
        for (index, keyCode) in functionKeys.enumerated() {
            names[keyCode] = "F\(index + 1)"
        }
        return names
    }()
}
