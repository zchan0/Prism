import AppKit
import SwiftUI

/// One tool in the toolbox.
///
/// A tool owns its state and tells the shell what to draw. The shell draws the panels: a click on the tool's icon
/// opens a quick panel with `controlsView()`, and the tool's tab in the hub shows the same controls above
/// `settingsView()`. A tool that needs more room opens its own window with `ToolWindowController`.
@MainActor
public protocol Tool: AnyObject {
    /// Stable and used for every name the tool persists: preferences, the status item's autosave name.
    /// Renaming it loses the person's settings, so it must not change.
    static var id: ToolID { get }

    var title: String { get }
    var symbolName: String { get }
    /// Draws only the symbol's primary layer, such as Lumos's wand without its stars while the Mac may sleep.
    var symbolPrimaryLayerOnly: Bool { get }
    /// One line, such as "24:12 left" or "119 GB free".
    var summary: String { get }

    /// Called once, when the app is ready. Not called for tools the person has turned off.
    func start()
    /// Called when the tool is turned off, and when the app quits.
    func stop()

    /// The tool's icons in the menu bar, left to right; most tools have one. Asked once a second while the tool is
    /// on. Returning the same image instance as last time skips the repaint.
    func statusIcons() -> [StatusIcon]
    /// What the tool does: all of its quick panel, and the top of its tab in the hub.
    func controlsView() -> AnyView
    /// How the tool is configured: only on its tab in the hub. Nil when there is nothing to configure.
    func settingsView() -> AnyView?
}

public extension Tool {
    var symbolPrimaryLayerOnly: Bool { false }
    func statusIcons() -> [StatusIcon] { [] }
    func settingsView() -> AnyView? { nil }
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
    /// Reachable only from the hub.
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
