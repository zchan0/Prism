import AppKit
import SwiftUI

/// One line in a `PanelCard`: an optional symbol, a title with an optional note under it, and a control on the right.
///
/// The shell and every tool use this, so a tool's controls and its settings line up with the shell's own switches.
public struct PanelRow<Accessory: View>: View {
    private let title: String
    private let symbol: String?
    private let note: String?
    private let accessory: Accessory
    @Environment(\.isEnabled) private var isEnabled

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
                    .panelInk(.tertiary)
                    .frame(width: 16)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(PanelFont.title)
                    .panelInk(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let note {
                    Text(note)
                        .font(PanelFont.note)
                        .panelInk(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .opacity(isEnabled ? 1 : 0.5)
            Spacer(minLength: 8)
            accessory
        }
        .padding(.horizontal, PanelDivider.cardInset)
        .padding(.vertical, note == nil ? 4 : 8)
        .frame(minHeight: PanelRowMetrics.minHeight)
    }
}

public enum PanelRowMetrics {
    public static let minHeight: CGFloat = 38
}

/// The switch every panel uses, small in a row and large at the top of a card or a page.
///
/// Drawn by hand: the panels are never key windows, and AppKit draws a switch in a window that is not key in grey
/// whether it is on or off.
public struct PanelSwitch: View {
    public enum Size {
        case regular
        case large
    }

    private let isOn: Binding<Bool>
    private let size: Size

    public init(isOn: Binding<Bool>, size: Size = .regular) {
        self.isOn = isOn
        self.size = size
    }

    public var body: some View {
        Toggle("", isOn: isOn)
            .labelsHidden()
            .toggleStyle(PanelSwitchStyle(size: size))
    }
}

private struct PanelSwitchStyle: ToggleStyle {
    let size: PanelSwitch.Size

    func makeBody(configuration: Configuration) -> some View {
        PanelSwitchBody(configuration: configuration, size: size)
    }
}

private struct PanelSwitchBody: View {
    let configuration: ToggleStyleConfiguration
    let size: PanelSwitch.Size
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let isOn = configuration.isOn
        let width: CGFloat = size == .large ? 42 : 34
        let height: CGFloat = size == .large ? 24 : 20
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack {
                // Only the track fades while disabled: a faded white knob disappears into a light track.
                Capsule()
                    .fill(Color(nsColor: isOn ? Palette.accent : Palette.switchOff))
                    .opacity(isEnabled ? 1 : 0.4)
                    .animation(.easeInOut(duration: 0.2), value: isOn)
                if reduceMotion {
                    // Two knobs that trade places by fading, so nothing slides.
                    knob.frame(maxWidth: .infinity, alignment: .leading).opacity(isOn ? 0 : 1)
                    knob.frame(maxWidth: .infinity, alignment: .trailing).opacity(isOn ? 1 : 0)
                } else {
                    knob.frame(maxWidth: .infinity, alignment: isOn ? .trailing : .leading)
                }
            }
            .animation(PanelMotion.spring(reduced: reduceMotion), value: isOn)
            .frame(width: width, height: height)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
    }

    private var knob: some View {
        Circle()
            .fill(.white)
            .shadow(color: .black.opacity(0.28), radius: 1, y: 0.5)
            .padding(2)
    }
}

/// The capsule behind a text button, so a button and a shortcut field without a shortcut look the same.
struct CapsuleButtonLabel: View {
    let title: String
    let hovered: Bool
    var isProminent = false

    var body: some View {
        Text(title)
            .font(isProminent ? PanelFont.title.weight(.semibold) : PanelFont.title)
            .panelInk(isProminent ? .fixed(Palette.accentInk) : .primary)
            .lineLimit(1)
            .padding(.horizontal, 11)
            .frame(height: 24)
            .background(Capsule().fill(Color(nsColor: fill)))
            .contentShape(Capsule())
    }

    private var fill: NSColor {
        if isProminent { return Palette.selection }
        return hovered ? Palette.hover : Palette.chip
    }
}

/// A small text button that sits at the end of a `PanelRow`, such as Clear….
public struct PanelButton: View {
    public enum Style {
        case regular
        /// In the accent color, for the one thing a card asks the person to do, such as installing an update.
        case prominent
    }

    private let title: String
    private let style: Style
    private let action: @MainActor () -> Void
    @State private var hovered = false
    @Environment(\.isEnabled) private var isEnabled

    public init(_ title: String, style: Style = .regular, action: @escaping @MainActor () -> Void) {
        self.title = title
        self.style = style
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            CapsuleButtonLabel(title: title, hovered: hovered && isEnabled, isProminent: style == .prominent)
        }
        .buttonStyle(PanelPressStyle())
        .fixedSize()
        .opacity(isEnabled ? 1 : 0.4)
        .onHover { hovered = $0 }
    }
}

/// A pop-up button that sits at the end of a `PanelRow`: the chosen option in a capsule, and a menu of the options.
public struct PanelPopUp<Value: Hashable>: View {
    private let selection: Binding<Value>
    private let options: [Value]
    private let title: (Value) -> String
    @State private var hovered = false
    @Environment(\.isEnabled) private var isEnabled

    public init(selection: Binding<Value>, options: [Value], title: @escaping (Value) -> String) {
        self.selection = selection
        self.options = options
        self.title = title
    }

    public var body: some View {
        Menu {
            Picker("", selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(title(option)).tag(option)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            HStack(spacing: 3) {
                Text(title(selection.wrappedValue))
                    .font(PanelFont.title)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .panelInk(.secondary)
            }
            .panelInk(.primary)
            .padding(.leading, 11)
            .padding(.trailing, 7)
            .frame(height: 24)
            .background(Capsule().fill(Color(nsColor: hovered && isEnabled ? Palette.hover : Palette.chip)))
            .contentShape(Capsule())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .opacity(isEnabled ? 1 : 0.4)
        .onHover { hovered = $0 }
        .accessibilityValue(title(selection.wrappedValue))
    }
}

/// The chosen option and a down arrow in a capsule, which opens a menu of the options under it, such as the filter in
/// Pensieve's history.
///
/// The menu is an `NSMenu` popped up under the capsule, the way the menu of a tool's icon is, so it opens and picks
/// in a panel whose app is not active.
public struct PanelMenuButton<Value: Hashable>: View {
    private let selection: Value
    private let options: [Value]
    private let title: (Value) -> String
    private let select: @MainActor (Value) -> Void
    @State private var anchor = MenuAnchor()
    @State private var hovered = false

    public init(selection: Value, options: [Value], title: @escaping (Value) -> String, select: @escaping @MainActor (Value) -> Void) {
        self.selection = selection
        self.options = options
        self.title = title
        self.select = select
    }

    public var body: some View {
        Button {
            anchor.view?.popUp()
        } label: {
            HStack(spacing: 4) {
                Text(title(selection))
                    .font(PanelFont.title)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .panelInk(.secondary)
            }
            .panelInk(.primary)
            .padding(.leading, 11)
            .padding(.trailing, 9)
            .frame(height: 24)
            .background(Capsule().fill(Color(nsColor: hovered ? Palette.hover : Palette.chip)))
            .contentShape(Capsule())
        }
        .buttonStyle(PanelPressStyle())
        .fixedSize()
        .background(MenuAnchorView(
            anchor: anchor,
            titles: options.map(title),
            selectedIndex: options.firstIndex(of: selection),
            choose: { index in select(options[index]) }
        ))
        .onHover { hovered = $0 }
        .accessibilityValue(title(selection))
    }
}

@MainActor
private final class MenuAnchor {
    weak var view: MenuAnchorNSView?
}

private struct MenuAnchorView: NSViewRepresentable {
    let anchor: MenuAnchor
    let titles: [String]
    let selectedIndex: Int?
    let choose: @MainActor (Int) -> Void

    func makeNSView(context: Context) -> MenuAnchorNSView {
        let view = MenuAnchorNSView()
        anchor.view = view
        return view
    }

    func updateNSView(_ view: MenuAnchorNSView, context: Context) {
        anchor.view = view
        view.titles = titles
        view.selectedIndex = selectedIndex
        view.choose = choose
    }
}

/// Sits behind the capsule, so the menu can open right under it.
final class MenuAnchorNSView: NSView {
    var titles: [String] = []
    var selectedIndex: Int?
    var choose: (@MainActor (Int) -> Void)?
    /// The menu while it is open.
    private(set) var openMenu: NSMenu?

    override var isFlipped: Bool { true }

    func popUp() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let target = MenuTarget { [weak self] index in self?.choose?(index) }
        for (index, title) in titles.enumerated() {
            let item = NSMenuItem(title: title, action: #selector(MenuTarget.chosen(_:)), keyEquivalent: "")
            item.target = target
            item.tag = index
            item.state = index == selectedIndex ? .on : .off
            menu.addItem(item)
        }
        openMenu = menu
        // Returns once the menu closes, after the chosen item's action.
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: bounds.height + 4), in: self)
        openMenu = nil
        withExtendedLifetime(target) {}
    }
}

@MainActor
private final class MenuTarget: NSObject {
    private let choose: @MainActor (Int) -> Void

    init(_ choose: @escaping @MainActor (Int) -> Void) {
        self.choose = choose
    }

    @objc func chosen(_ sender: NSMenuItem) {
        choose(sender.tag)
    }
}

#if DEBUG
public enum PanelMenuButtonDebug {
    /// Opens the first `PanelMenuButton`'s menu in `window` the way a click does, and picks the item at `index` once
    /// the menu is on screen. `whileOpen` runs with the menu open. True when the menu opened and the item was picked.
    @MainActor
    public static func pick(_ index: Int, in window: NSWindow, whileOpen: @escaping @MainActor () -> Void = {}) -> Bool {
        guard let anchor = window.contentView.flatMap({ firstAnchor(in: $0) }),
              anchor.titles.indices.contains(index) else { return false }
        let state = PickState()
        let original = anchor.choose
        anchor.choose = { chosen in
            state.picked = chosen == index
            original?(chosen)
        }
        let observer = NotificationCenter.default.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: nil) { _ in
            MainActor.assumeIsolated { state.opened = true }
        }
        // Menu tracking runs the run loop in its own mode, which `.common` includes.
        let timer = Timer(timeInterval: 0.8, repeats: false) { _ in
            MainActor.assumeIsolated {
                guard let menu = anchor.openMenu else { return }
                whileOpen()
                menu.performActionForItem(at: index)
                menu.cancelTracking()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        anchor.popUp()
        timer.invalidate()
        NotificationCenter.default.removeObserver(observer)
        anchor.choose = original
        return state.opened && state.picked
    }

    @MainActor
    private final class PickState {
        var opened = false
        var picked = false
    }

    @MainActor
    private static func firstAnchor(in view: NSView) -> MenuAnchorNSView? {
        if let anchor = view as? MenuAnchorNSView { return anchor }
        for subview in view.subviews {
            if let anchor = firstAnchor(in: subview) { return anchor }
        }
        return nil
    }
}
#endif

/// A hairline across a panel, such as above a window's footer.
public struct PanelDivider: View {
    static let cardInset: CGFloat = 12

    private let inset: CGFloat

    public init() {
        inset = 0
    }

    private init(inset: CGFloat) {
        self.inset = inset
    }

    /// Between the rows of a `PanelCard`: as far in from each side as the rows' text.
    public static var inCard: PanelDivider { PanelDivider(inset: cardInset) }

    public var body: some View {
        Rectangle()
            .fill(Color(nsColor: Palette.hair))
            .frame(height: 1)
            .padding(.horizontal, inset)
            .accessibilityHidden(true)
    }
}
