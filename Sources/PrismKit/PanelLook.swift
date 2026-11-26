import AppKit
import Observation
import SwiftUI

// The looks being tried for Liquid Glass. Each setting's first case is how Prism looked before; the Experiments
// section on General switches them while one is picked.

/// How a panel groups its rows.
public enum PanelGrouping: String, CaseIterable, Sendable {
    /// Nearly opaque cards, with the glass showing only between them.
    case cards
    /// A thin wash instead of a card, so the glass shows through.
    case plates
    /// A list's rows straight on the glass with only the lines between them; other cards as plates.
    case bare
}

/// What colors a panel's text and symbols take.
public enum PanelInkStyle: String, CaseIterable, Sendable {
    /// The palette's fixed inks.
    case palette
    /// The system's primary, secondary and tertiary styles, which adapt to what is behind the glass.
    case system
}

/// What is behind a floating panel's content.
public enum PanelBackground: String, CaseIterable, Sendable {
    /// Liquid Glass on macOS 26 and later, the popover material before.
    case glass
    /// The popover material everywhere, to compare with the glass.
    case material
}

/// How the Prism window lays out its list of pages.
public enum WindowSidebar: String, CaseIterable, Sendable {
    /// A card of Prism's own, drawn next to the page.
    case custom
    /// The system's sidebar, from a split view.
    case system
}

@MainActor
@Observable
public final class LookSettings {
    public static let shared = LookSettings(defaults: .standard, overrides: debugOverrides)

    private enum Key {
        static let grouping = "shell.look.grouping"
        static let ink = "shell.look.ink"
        static let background = "shell.look.panelBackground"
        static let sidebar = "shell.look.sidebar"
    }

    public private(set) var grouping: PanelGrouping
    public private(set) var ink: PanelInkStyle
    public private(set) var background: PanelBackground
    public private(set) var sidebar: WindowSidebar

    @ObservationIgnored private let defaults: UserDefaults

    /// `overrides`, such as "plates+system+glass+system", replaces the saved settings in order without saving
    /// anything; a screenshot run uses it.
    public init(defaults: UserDefaults = .standard, overrides: String? = nil) {
        self.defaults = defaults
        grouping = defaults.string(forKey: Key.grouping).flatMap(PanelGrouping.init(rawValue:)) ?? .cards
        ink = defaults.string(forKey: Key.ink).flatMap(PanelInkStyle.init(rawValue:)) ?? .palette
        background = defaults.string(forKey: Key.background).flatMap(PanelBackground.init(rawValue:)) ?? .glass
        sidebar = defaults.string(forKey: Key.sidebar).flatMap(WindowSidebar.init(rawValue:)) ?? .custom
        guard let overrides else { return }
        let parts = overrides.split(separator: "+").map(String.init)
        if parts.count > 0, let value = PanelGrouping(rawValue: parts[0]) { grouping = value }
        if parts.count > 1, let value = PanelInkStyle(rawValue: parts[1]) { ink = value }
        if parts.count > 2, let value = PanelBackground(rawValue: parts[2]) { background = value }
        if parts.count > 3, let value = WindowSidebar(rawValue: parts[3]) { sidebar = value }
    }

    /// What the parts of a floating panel draw with.
    public var panel: PanelLook { PanelLook(grouping: grouping, ink: ink) }

    public func setGrouping(_ grouping: PanelGrouping) {
        self.grouping = grouping
        defaults.set(grouping.rawValue, forKey: Key.grouping)
    }

    public func setInk(_ ink: PanelInkStyle) {
        self.ink = ink
        defaults.set(ink.rawValue, forKey: Key.ink)
    }

    public func setBackground(_ background: PanelBackground) {
        self.background = background
        defaults.set(background.rawValue, forKey: Key.background)
    }

    public func setSidebar(_ sidebar: WindowSidebar) {
        self.sidebar = sidebar
        defaults.set(sidebar.rawValue, forKey: Key.sidebar)
    }

    private static var debugOverrides: String? {
        #if DEBUG
        ProcessInfo.processInfo.environment["PRISM_LOOK"]
        #else
        nil
        #endif
    }
}

/// How a panel part draws where it is: the Prism window keeps `.window`, and a floating panel's root sets the look
/// being tried.
public struct PanelLook: Equatable, Sendable {
    public var grouping: PanelGrouping
    public var ink: PanelInkStyle

    public init(grouping: PanelGrouping, ink: PanelInkStyle) {
        self.grouping = grouping
        self.ink = ink
    }

    public static let window = PanelLook(grouping: .cards, ink: .palette)

    /// Parts drawn straight on the glass, such as a keycap, take a see-through fill instead of an opaque one.
    public var isTranslucent: Bool { grouping != .cards }
}

private struct PanelLookKey: EnvironmentKey {
    static let defaultValue = PanelLook.window
}

public extension EnvironmentValues {
    var panelLook: PanelLook {
        get { self[PanelLookKey.self] }
        set { self[PanelLookKey.self] = newValue }
    }
}

/// The three levels of text and symbols: names, what goes under them, and small print.
public enum PanelInk: Sendable {
    case primary
    case secondary
    case tertiary
    /// A color that means something, such as the accent or a warning, the same in every look.
    case fixed(NSColor)

    var paletteColor: NSColor {
        switch self {
        case .primary: Palette.ink
        case .secondary: Palette.ink2
        case .tertiary: Palette.ink3
        case .fixed(let color): color
        }
    }
}

public extension View {
    /// For the root of a floating panel's content: its parts take the look being tried, and follow a change to it.
    func followsPanelLook() -> some View {
        modifier(FollowsPanelLook())
    }

    /// Colors text and symbols with the palette's ink, or with the system's on a panel that tries the system look.
    func panelInk(_ ink: PanelInk) -> some View {
        modifier(PanelInkModifier(ink: ink))
    }
}

private struct FollowsPanelLook: ViewModifier {
    func body(content: Content) -> some View {
        content.environment(\.panelLook, LookSettings.shared.panel)
    }
}

private struct PanelInkModifier: ViewModifier {
    let ink: PanelInk
    @Environment(\.panelLook) private var look

    func body(content: Content) -> some View {
        switch (look.ink, ink) {
        case (.palette, _), (_, .fixed):
            content.foregroundStyle(Color(nsColor: ink.paletteColor))
        case (.system, .primary):
            content.foregroundStyle(.primary)
        case (.system, .secondary):
            content.foregroundStyle(.secondary)
        case (.system, .tertiary):
            content.foregroundStyle(.tertiary)
        }
    }
}
