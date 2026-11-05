import SwiftUI

/// One line in a panel: an optional symbol, a title with an optional note under it, and a control on the right.
///
/// The shell and every tool use this, so a tool's controls and its settings line up with the shell's own switches.
public struct PanelRow<Accessory: View>: View {
    private let title: String
    private let symbol: String?
    private let note: String?
    private let accessory: Accessory

    public init(_ title: String, symbol: String? = nil, note: String? = nil, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.symbol = symbol
        self.note = note
        self.accessory = accessory()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(nsColor: Palette.ink3))
                    .frame(width: 18)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(nsColor: Palette.ink))
                    .fixedSize(horizontal: false, vertical: true)
                if let note {
                    Text(note)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color(nsColor: Palette.ink3))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            accessory
        }
        .padding(.vertical, 7)
    }
}

/// The small switch every panel row uses.
///
/// Drawn by hand: the panels are never key windows, and AppKit draws a switch in a window that is not key in grey
/// whether it is on or off.
public struct PanelSwitch: View {
    private let isOn: Binding<Bool>

    public init(isOn: Binding<Bool>) {
        self.isOn = isOn
    }

    public var body: some View {
        Toggle("", isOn: isOn)
            .labelsHidden()
            .toggleStyle(PanelSwitchStyle())
    }
}

private struct PanelSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        PanelSwitchBody(configuration: configuration)
    }
}

private struct PanelSwitchBody: View {
    let configuration: ToggleStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.18)) { configuration.isOn.toggle() }
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? Color(nsColor: .controlAccentColor) : Color(nsColor: Palette.switchOff))
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.2), radius: 0.8, y: 0.5)
                    .padding(2)
            }
            .frame(width: 28, height: 16)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityAddTraits(.isToggle)
    }
}

public extension View {
    /// A picker as a compact pop-up button that sits at the end of a `PanelRow`.
    func panelMenu() -> some View {
        labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
            .fixedSize()
    }
}

/// A hairline between the sections of a panel.
public struct PanelDivider: View {
    public init() {}

    public var body: some View {
        Divider().overlay(Color(nsColor: Palette.hair))
    }
}
