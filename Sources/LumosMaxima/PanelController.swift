import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class PanelLayout {
    var isShown = false
}

@MainActor
final class PanelController {
    static let width: CGFloat = 330
    static let cornerRadius: CGFloat = 16
    static let menuBarGap: CGFloat = 6
    static let screenMargin: CGFloat = 8

    var onVisibilityChange: ((Bool) -> Void)?
    private let model: AppModel
    private var panel: NSPanel?
    private var anchor: NSRect?
    private var visibleFrame: NSRect?
    private var contentHeight: CGFloat = 0
    private var outsideClickMonitor: Any?
    private let layout = PanelLayout()

    init(model: AppModel, actions: PanelActions) {
        self.model = model
        let host = LivePanelView(
            model: model,
            layout: layout,
            actions: actions,
            onHeightChange: { [weak self] height in self?.contentHeightChanged(height) }
        )
        panel = Self.makePanel(rootView: host)
    }

    var isShown: Bool { panel?.isVisible ?? false }

    #if DEBUG
    var windowForDebug: NSWindow? { panel }
    #endif

    func toggle(below button: NSStatusBarButton) {
        if isShown {
            hide()
        } else {
            show(below: button)
        }
    }

    func show(below button: NSStatusBarButton) {
        guard let panel, let window = button.window, let screen = window.screen ?? NSScreen.main else { return }
        anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
        visibleFrame = screen.visibleFrame
        panel.contentView?.layoutSubtreeIfNeeded()
        // Never made key: with Liquid Glass a key borderless panel draws a dark rectangle around its rounded
        // corners (macOS 26).
        panel.orderFrontRegardless()
        reposition()
        layout.isShown = true
        model.uiTick()
        watchOutsideClicks()
        onVisibilityChange?(true)
    }

    func hide() {
        guard let panel, panel.isVisible else { return }
        panel.orderOut(nil)
        layout.isShown = false
        stopWatchingOutsideClicks()
        onVisibilityChange?(false)
    }

    private func contentHeightChanged(_ height: CGFloat) {
        contentHeight = height
        // The height arrives during SwiftUI's layout pass; resizing the window inside it leaves the glass content
        // view taller than the window by the size change.
        DispatchQueue.main.async { [weak self] in self?.reposition() }
    }

    // A glass panel resized while ordered out keeps drawing at a stale size once shown again, so the frame only
    // follows the content while the panel is on screen.
    private func reposition() {
        guard let panel, panel.isVisible, let anchor, let visibleFrame, contentHeight > 0 else { return }
        panel.setFrame(Self.frame(height: contentHeight, below: anchor, in: visibleFrame), display: true)
    }

    private func watchOutsideClicks() {
        guard outsideClickMonitor == nil else { return }
        // A global monitor only sees events sent to other apps, so clicks on the status item or the panel never
        // reach it.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.hide() }
        }
    }

    private func stopWatchingOutsideClicks() {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
    }

    /// The panel hangs below the item's left edge and stays inside the screen.
    static func frame(height: CGFloat, below anchor: NSRect, in visibleFrame: NSRect) -> NSRect {
        let x = max(visibleFrame.minX + screenMargin, min(anchor.minX, visibleFrame.maxX - screenMargin - width))
        let top = min(anchor.minY, visibleFrame.maxY) - menuBarGap
        let clamped = min(height, top - visibleFrame.minY - screenMargin)
        return NSRect(x: x, y: top - clamped, width: width, height: clamped)
    }

    static func makePanel(rootView: some View) -> NSPanel {
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

        let host = PanelHostingView(rootView: rootView)
        host.sizingOptions = []
        host.autoresizingMask = [.width, .height]
        if #available(macOS 26, *) {
            let glass = NSGlassEffectView()
            glass.cornerRadius = cornerRadius
            glass.contentView = host
            panel.contentView = glass
        } else {
            let background = NSVisualEffectView()
            background.material = .popover
            background.blendingMode = .behindWindow
            // The app is rarely active, so the default window-following state would keep the inactive look.
            background.state = .active
            background.maskImage = roundedMask(radius: cornerRadius)
            background.addSubview(host)
            panel.contentView = background
            host.frame = background.bounds
        }
        return panel
    }

    static func hostView(of panel: NSPanel) -> NSView? {
        if #available(macOS 26, *), let glass = panel.contentView as? NSGlassEffectView {
            return glass.contentView
        }
        return panel.contentView?.subviews.first
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

private final class PanelHostingView<Content: View>: NSHostingView<Content> {
    // Clicks arrive while another app is active; without this the first one only brings the panel forward.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
