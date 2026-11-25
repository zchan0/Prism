import AppKit
import SwiftUI

/// One tool in the toolbox.
///
/// A tool owns its state and tells the shell what to draw. A click on the tool's icon opens a panel with only
/// `controlsView()`. The tool's page in the Prism window starts with its name, `tagline` and switch, then shows
/// `controlsView()` when `showsControlsInWindow`, then `settingsView()`, and last its Menu Bar card with
/// `menuBarSettings()`.
@MainActor
public protocol Tool: AnyObject {
    /// Stable and used for every name the tool persists: preferences, the status item's autosave name.
    /// Renaming it loses the person's settings, so it must not change.
    static var id: ToolID { get }

    var title: String { get }
    /// What the tool does, in one sentence, under its name at the top of its page.
    var tagline: String { get }
    var symbolName: String { get }
    /// Draws only the symbol's primary layer, such as Lumos's wand without its stars while the Mac may sleep.
    var symbolPrimaryLayerOnly: Bool { get }
    /// The color of the tool's tile, while the tool is on.
    var tint: ToolTint { get }
    /// What the tool is doing now, short enough for one line in the Prism window's list, such as "29 min left".
    var summary: String { get }
    /// Whether the tool's page in the Prism window starts with `controlsView()`. A tool whose settings already hold
    /// everything its controls offer says no.
    var showsControlsInWindow: Bool { get }
    /// Whether relaunching Prism now would cut short what the tool is doing, so an update waits.
    var blocksRelaunch: Bool { get }

    /// Called once, when the app is ready. Not called for tools the person has turned off.
    func start()
    /// Called when the tool is turned off, and when the app quits.
    func stop()

    /// Prism is about to relaunch for an update. The tool saves what it needs to carry on in the new process, and
    /// returns what has to be held for it in between; nil when there is nothing to carry on. After this, `stop()`
    /// must not end what the tool is doing.
    func prepareForRelaunch() -> RelaunchHold?
    /// The relaunch after `prepareForRelaunch()` did not happen and this process keeps running: the tool drops what
    /// it saved and stops as usual again.
    func relaunchCancelled()

    /// The tool's icons in the menu bar, left to right; most tools have one. Asked once a second while the tool is
    /// on. Returning the same image instance as last time skips the repaint.
    func statusIcons() -> [StatusIcon]
    /// What the tool does: the body of its panel. `ToolPanelActions` in the environment closes the panel or opens
    /// the tool's page in the Prism window.
    func controlsView() -> AnyView
    /// How the tool is configured: only on its page in the Prism window, each group in a `PanelSection`. Nil when
    /// there is nothing to configure.
    func settingsView() -> AnyView?
    /// The tool's own menu bar settings, which the Prism window puts in its Menu Bar card after Show in the menu bar.
    func menuBarSettings() -> MenuBarSettings?
}

public extension Tool {
    var symbolPrimaryLayerOnly: Bool { false }
    var tint: ToolTint { Palette.neutral }
    var showsControlsInWindow: Bool { true }
    var blocksRelaunch: Bool { false }
    func prepareForRelaunch() -> RelaunchHold? { nil }
    func relaunchCancelled() {}
    func statusIcons() -> [StatusIcon] { [] }
    func settingsView() -> AnyView? { nil }
    func menuBarSettings() -> MenuBarSettings? { nil }

    /// Opens the tool's page in the Prism window, from a window of the tool's own such as Pensieve's history.
    func openPageInPrismWindow() {
        ToolPageRoute.open(type(of: self).id)
    }
}

/// What has to be kept up while Prism relaunches for an update, between the old process quitting and the new one
/// taking over.
public struct RelaunchHold: Sendable, Equatable {
    public var keepsSystemAwake: Bool
    public var keepsDisplayAwake: Bool
    /// Files to keep open, such as Lumos's lid flag, whose helper treats a flag nobody holds as a session that ended.
    public var heldFiles: [String]

    public init(keepsSystemAwake: Bool = false, keepsDisplayAwake: Bool = false, heldFiles: [String] = []) {
        self.keepsSystemAwake = keepsSystemAwake
        self.keepsDisplayAwake = keepsDisplayAwake
        self.heldFiles = heldFiles
    }

    public var isEmpty: Bool { !keepsSystemAwake && !keepsDisplayAwake && heldFiles.isEmpty }

    /// One hold that covers every tool's.
    public static func merged(_ holds: [RelaunchHold]) -> RelaunchHold {
        var merged = RelaunchHold()
        for hold in holds {
            merged.keepsSystemAwake = merged.keepsSystemAwake || hold.keepsSystemAwake
            merged.keepsDisplayAwake = merged.keepsDisplayAwake || hold.keepsDisplayAwake
            for file in hold.heldFiles where !merged.heldFiles.contains(file) {
                merged.heldFiles.append(file)
            }
        }
        return merged
    }
}

/// How a tool reaches its page in the Prism window. The app sets it when it starts.
@MainActor
public enum ToolPageRoute {
    public static var open: (ToolID) -> Void = { _ in }
}

/// Rows for the Prism window's Menu Bar card. The shell draws the line above them; the rows draw the lines between
/// themselves, with `PanelDivider.inCard`.
@MainActor
public struct MenuBarSettings {
    public let rows: AnyView
    /// Under the card.
    public let note: String?

    public init(rows: AnyView, note: String? = nil) {
        self.rows = rows
        self.note = note
    }
}

/// One of a tool's icons in the menu bar.
@MainActor
public struct StatusIcon {
    /// Stable within the tool: it names the icon's saved place in the menu bar.
    public let id: String
    public let image: NSImage

    public init(id: String, image: NSImage) {
        self.id = id
        self.image = image
    }
}

/// A tool's identity. A wrapper rather than a bare `String` so an id cannot be passed where a label belongs.
public struct ToolID: Hashable, Sendable, RawRepresentable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }
}

/// Whether a tool has its own icon in the menu bar.
public enum MenuBarPlacement: String, CaseIterable, Sendable {
    case ownIcon
    /// Reachable only from the Prism window. The raw value is saved, so it keeps its old name.
    case hubOnly

    public var id: String { rawValue }
}

/// The shell's view of a tool, built once at launch.
@MainActor
public struct ToolRegistration {
    public let tool: Tool
    /// Whether a tool gets its own icon by default, before the person changes it.
    public let defaultPlacement: MenuBarPlacement

    public init(_ tool: Tool, defaultPlacement: MenuBarPlacement) {
        self.tool = tool
        self.defaultPlacement = defaultPlacement
    }

    public var id: ToolID { type(of: tool).id }
}

/// What a tool's controls can ask of the panel they are in. In the Prism window both do nothing.
public struct ToolPanelActions: Sendable {
    /// Closes the panel.
    public var close: @MainActor () -> Void
    /// Closes the panel and opens the tool's page in the Prism window.
    public var openSettings: @MainActor () -> Void

    public init(close: @escaping @MainActor () -> Void, openSettings: @escaping @MainActor () -> Void) {
        self.close = close
        self.openSettings = openSettings
    }

    public static let none = ToolPanelActions(close: {}, openSettings: {})
}

private struct ToolPanelActionsKey: EnvironmentKey {
    static let defaultValue = ToolPanelActions.none
}

public extension EnvironmentValues {
    var toolPanel: ToolPanelActions {
        get { self[ToolPanelActionsKey.self] }
        set { self[ToolPanelActionsKey.self] = newValue }
    }
}
