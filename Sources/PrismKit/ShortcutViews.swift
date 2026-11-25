import AppKit
import SwiftUI

/// A shortcut's keys, one keycap each, which a click turns into a field that waits for the combination. Without a
/// shortcut it is a button that says so.
///
/// `name` is what the shortcut is for, such as an app's name, and is what VoiceOver reads for the field.
public struct ShortcutButton: View {
    private let name: String
    private let shortcut: Shortcut?
    private let isRecording: Bool
    private let start: @MainActor () -> Void
    @State private var hovered = false

    public init(name: String, shortcut: Shortcut?, isRecording: Bool, start: @escaping @MainActor () -> Void) {
        self.name = name
        self.shortcut = shortcut
        self.isRecording = isRecording
        self.start = start
    }

    public var body: some View {
        Button(action: start) {
            label.contentShape(Rectangle())
        }
        .buttonStyle(PanelPressStyle())
        .fixedSize()
        .onHover { hovered = $0 }
        .accessibilityLabel(name)
        .accessibilityValue(value)
    }

    @ViewBuilder private var label: some View {
        if isRecording {
            Text(Strings.typeShortcut)
                .font(PanelFont.section)
                .foregroundStyle(Color(nsColor: Palette.accentInk))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(height: 22)
                .background(Capsule().fill(Color(nsColor: Palette.selection)))
                .overlay(Capsule().strokeBorder(Color(nsColor: Palette.accent), lineWidth: 1.5))
        } else if let shortcut {
            ShortcutKeys(shortcut)
        } else {
            CapsuleButtonLabel(title: Strings.addShortcut, hovered: hovered)
        }
    }

    private var value: String {
        if isRecording { return Strings.typeShortcut }
        return shortcut?.text ?? Strings.addShortcut
    }
}

/// A shortcut drawn as keycaps, without the recording around it.
public struct ShortcutKeys: View {
    private let keys: [String]

    public init(_ shortcut: Shortcut) {
        keys = shortcut.keys
    }

    /// Keys that are not a recorded shortcut, such as ↩ for a window's own commands.
    public init(keys: [String]) {
        self.keys = keys
    }

    public var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Keycap(key: key)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(keys.joined())
    }
}

public struct Keycap: View {
    private let key: String

    public init(key: String) {
        self.key = key
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        Text(verbatim: key)
            .font(PanelFont.note)
            .foregroundStyle(Color(nsColor: Palette.ink))
            .padding(.horizontal, 4)
            .frame(minWidth: 20, minHeight: 20, maxHeight: 20)
            .background(shape.fill(Color(nsColor: Palette.key)))
            .overlay(shape.strokeBorder(Color(nsColor: Palette.keyBorder), lineWidth: 1))
    }
}
