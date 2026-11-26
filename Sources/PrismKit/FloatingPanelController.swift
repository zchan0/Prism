import AppKit
import SwiftUI

/// A borderless panel that hangs off an anchor and closes when the person clicks elsewhere.
///
/// Each tool's panel uses this. When the content changes height while the panel is open, the panel follows it
/// smoothly and keeps its top edge in place; the content should hug the top edge of the panel for that to look right.
@MainActor
public final class FloatingPanelController {
    public enum Placement: Equatable, Sendable {
        /// Grows downward from the anchor, for a menu bar item.
        case below
        /// Grows upward from the anchor, for a window near the bottom of the screen.
        case above
    }

    public static let menuBarGap: CGFloat = 6
    public static let screenMargin: CGFloat = 8

    private static let instances = NSHashTable<FloatingPanelController>.weakObjects()

    public var onVisibilityChange: ((Bool) -> Void)?

    private let width: CGFloat
    private let cornerRadius: CGFloat
    private let panel: NSPanel
    private var anchor: NSRect?
    private var placement = Placement.below
    private var visibleFrame: NSRect?
    private var contentHeight: CGFloat = 0
    /// A panel that just opened takes its content's height at once; only later changes are animated.
    private var shownAt: TimeInterval = 0
    private var outsideClickMonitor: Any?
    private let hosting: NSHostingView<AnyView>
    /// The background the panel has, so a different one picked meanwhile takes over at the next opening.
    private var backgroundLook: PanelBackground

    public init(width: CGFloat, cornerRadius: CGFloat = 16, content: AnyView) {
        self.width = width
        self.cornerRadius = cornerRadius
        hosting = NSHostingView(rootView: content)
        // The panel's height follows `setContentHeight`, not the hosting view's own idea of its size.
        hosting.sizingOptions = []
        backgroundLook = LookSettings.shared.background
        panel = Self.makePanel(width: width, cornerRadius: cornerRadius, host: hosting)
        Self.instances.add(self)
    }

    /// Closes every panel that is open, each through `hide()`, so their owners hear about it.
    public static func hideAll() {
        for controller in instances.allObjects {
            controller.hide()
        }
    }

    public var isShown: Bool { panel.isVisible }
    public var window: NSWindow { panel }

    public func setContent(_ content: AnyView) {
        hosting.rootView = content
    }

    public func show(below button: NSStatusBarButton) {
        guard let window = button.window, let screen = window.screen ?? NSScreen.main else { return }
        show(
            anchoredAt: window.convertToScreen(button.convert(button.bounds, to: nil)),
            placement: .below,
            on: screen
        )
    }

    public func show(anchoredAt rect: NSRect, placement: Placement, on screen: NSScreen) {
        if !panel.isVisible, backgroundLook != LookSettings.shared.background {
            Self.setBackground(of: panel, cornerRadius: cornerRadius, host: hosting)
            backgroundLook = LookSettings.shared.background
        }
        anchor = rect
        self.placement = placement
        visibleFrame = screen.visibleFrame
        shownAt = ProcessInfo.processInfo.systemUptime
        panel.contentView?.layoutSubtreeIfNeeded()
        // Never made key: with Liquid Glass a key borderless panel draws a dark rectangle around its rounded corners.
        panel.orderFrontRegardless()
        reposition()
        watchOutsideClicks()
        onVisibilityChange?(true)
    }

    /// Lays the content out again after it changed while the panel is open.
    public func refresh() {
        guard isShown else { return }
        panel.contentView?.layoutSubtreeIfNeeded()
        reposition()
    }

    public func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        stopWatchingOutsideClicks()
        onVisibilityChange?(false)
    }

    /// SwiftUI reports the natural height here; the window follows it while it is on screen.
    public func setContentHeight(_ height: CGFloat) {
        contentHeight = height
        DispatchQueue.main.async { [weak self] in self?.reposition() }
    }

    private func reposition() {
        guard panel.isVisible, let anchor, let visibleFrame, contentHeight > 0 else { return }
        let frame = Self.frame(height: contentHeight, from: anchor, placement: placement, in: visibleFrame, width: width)
        guard frame != panel.frame else { return }
        let settled = ProcessInfo.processInfo.systemUptime - shownAt > 0.2
        guard settled, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            panel.setFrame(frame, display: true)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
        }
    }

    /// The panel hangs off one edge of its anchor, aligns with the anchor's left edge, and stays inside the screen.
    public static func frame(
        height: CGFloat,
        from anchor: NSRect,
        placement: Placement,
        in visibleFrame: NSRect,
        width: CGFloat
    ) -> NSRect {
        let x = max(visibleFrame.minX + screenMargin, min(anchor.minX, visibleFrame.maxX - screenMargin - width))
        let bottomLimit = visibleFrame.minY + screenMargin
        switch placement {
        case .below:
            // A menu bar item sits at the very top edge, so its own edge is the ceiling, not the visible frame's.
            let top = min(anchor.minY, visibleFrame.maxY) - menuBarGap
            let clamped = min(height, max(0, top - bottomLimit))
            return NSRect(x: x, y: top - clamped, width: width, height: clamped)
        case .above:
            let bottom = anchor.maxY + menuBarGap
            let clamped = min(height, max(0, visibleFrame.maxY - screenMargin - bottom))
            return NSRect(x: x, y: bottom, width: width, height: clamped)
        }
    }

    private func watchOutsideClicks() {
        guard outsideClickMonitor == nil else { return }
        // A global monitor only sees events sent to other apps, so clicks on the status item or the panel never reach it.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.hide() }
        }
    }

    private func stopWatchingOutsideClicks() {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
    }

    private static func makePanel(width: CGFloat, cornerRadius: CGFloat, host: NSView) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 420),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        setBackground(of: panel, cornerRadius: cornerRadius, host: host)
        return panel
    }

    /// Glass on macOS 26, the popover material before or when that look is picked, with `host` on it.
    static func setBackground(of panel: NSPanel, cornerRadius: CGFloat, host: NSView) {
        host.autoresizingMask = [.width, .height]
        if #available(macOS 26, *), LookSettings.shared.background == .glass {
            let glass = NSGlassEffectView()
            glass.cornerRadius = cornerRadius
            glass.contentView = host
            panel.contentView = glass
        } else {
            let background = materialBackground(cornerRadius: cornerRadius)
            background.addSubview(host)
            panel.contentView = background
            host.frame = background.bounds
        }
    }

    /// The popover material, rounded, and active even though the panel never becomes key.
    public static func materialBackground(cornerRadius: CGFloat) -> NSVisualEffectView {
        let background = NSVisualEffectView()
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        background.maskImage = roundedMask(radius: cornerRadius)
        return background
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let side = radius * 2 + 1
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

/// Clicks arrive while another app is active; without this the first one only brings the window forward.
public final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
