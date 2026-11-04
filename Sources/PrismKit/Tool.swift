import AppKit
import SwiftUI

/// One widget in the toolbox.
///
/// A tool owns its state and its windows, and tells the shell what to show. The shell never asks a tool what kind it
/// is: it reads `id`, `title` and `summary` for the hub, and calls into the tool through the methods below. That is
/// what keeps tools apart while they share one menu bar item, one panel window and one login item.
@MainActor
public protocol Tool: AnyObject {
    /// Stable and used for every name the tool persists: preferences, notifications, the status item's autosave name.
    /// Renaming it loses the person's settings, so it must not change.
    static var id: ToolID { get }

    var title: String { get }
    var symbolName: String { get }
    /// One line in the hub, such as "24:12 left" or "119 GB free". Cheap: it is read on every panel opening.
    var summary: String { get }

    /// Called once, when the app is ready. Not called for tools the person has turned off.
    func start()
    /// Called when the tool is turned off, and when the app quits.
    func stop()

    /// The tool's own controls, shown when its row is opened in the hub. Nil means the tool has nothing to configure.
    func settingsView() -> AnyView?

    /// A menu bar image, or nil for a tool that only lives in the hub. Called every second while the tool is on,
    /// so it must be cheap and should return nil when nothing it draws has changed.
    func statusItemImage() -> NSImage?

    /// The tool's own controls inside the hub panel, below its summary line. Nil keeps the row as a plain summary.
    func hubView() -> AnyView?

    /// A short panel that a click on the tool's own menu bar icon opens. Nil falls back to the hub.
    func quickPanel() -> AnyView?
}

public extension Tool {
    func settingsView() -> AnyView? { nil }
    func statusItemImage() -> NSImage? { nil }
    func hubView() -> AnyView? { nil }
    func quickPanel() -> AnyView? { nil }
}

/// A tool that opens its own panel from its menu bar icon, instead of the hub.
///
/// This is a separate protocol rather than a requirement of `Tool`, so a tool that has nothing but a row in the hub
/// does not have to implement an empty method.
@MainActor
public protocol MenuBarPresenter: AnyObject {
    func showPanel(below button: NSStatusBarButton)
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

/// How a tool shows up in the menu bar.
public enum MenuBarPlacement: String, CaseIterable, Sendable {
    /// Its own icon next to the shell's.
    case ownIcon
    /// Only inside the hub panel.
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
