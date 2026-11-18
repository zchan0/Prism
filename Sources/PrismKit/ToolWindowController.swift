import AppKit
import SwiftUI

/// A titled window for a tool that needs more room than a panel, such as a list to edit.
///
/// The content draws from the window's top edge, under a transparent title bar with no title. The window is exactly
/// as big as the content: the person cannot resize it, and when the content grows or shrinks, the window follows and
/// keeps its top edge in place.
///
/// Prism has no Dock icon, so showing the window activates the app first; otherwise the window would open behind the
/// app in front and never take the keyboard.
@MainActor
public final class ToolWindowController {
    public let window: NSWindow
    private var hasBeenShown = false

    /// The content sets the window's size through its SwiftUI frame, so it should have a fixed size.
    public init(title: String, content: AnyView) {
        let hosting = NSHostingView(rootView: content)
        hosting.sizingOptions = [.minSize, .maxSize]
        // Without this, SwiftUI keeps the content clear of the title bar.
        hosting.safeAreaRegions = []
        window = ToolWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]
        // The hosting view sizes the window through constraints it adds on the first update. Until then the window
        // has no size, and `show()` would centre an empty window.
        window.updateConstraintsIfNeeded()
    }

    public func show() {
        FloatingPanelController.hideAll()
        NSApp.activate()
        if !hasBeenShown {
            window.center()
            hasBeenShown = true
        }
        window.makeKeyAndOrderFront(nil)
    }
}

// Prism has no main menu, so nothing else turns ⌘W into a close.
private final class ToolWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if super.performKeyEquivalent(with: event) { return true }
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard modifiers == .command, event.charactersIgnoringModifiers?.lowercased() == "w" else { return false }
        performClose(nil)
        return true
    }
}
