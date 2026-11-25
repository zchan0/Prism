import AppKit
import SwiftUI

/// A panel that shows something beside another window, such as a large picture next to the list it is in, on the same
/// background as a tool's panel. It never takes the keyboard or a click, and it goes away with the window beside it.
@MainActor
public final class SidePanelController {
    public enum Side: Sendable {
        case left
        case right
    }

    public static let gap: CGFloat = 8

    private let panel: NSPanel
    private let hosting: NSHostingView<AnyView>
    private weak var host: NSWindow?
    private var side = Side.right
    private var hostObservers: [NSObjectProtocol] = []

    public init(cornerRadius: CGFloat = 24) {
        hosting = NSHostingView(rootView: AnyView(EmptyView()))
        // The panel takes the content's own size, which `fittingSize` reports only with this option.
        hosting.sizingOptions = [.intrinsicContentSize]
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        FloatingPanelController.setBackground(of: panel, cornerRadius: cornerRadius, host: hosting)
    }

    public var isShown: Bool { panel.isVisible }
    public var window: NSWindow { panel }

    /// Next to `host`, top edges lined up, on `side` when there is room there and on the other side when there is not.
    public func show(_ content: AnyView, beside host: NSWindow, preferring side: Side) {
        guard host.isVisible else {
            hide()
            return
        }
        hosting.rootView = content
        self.side = side
        if self.host !== host {
            stopFollowingHost()
            self.host = host
            followHost()
        }
        panel.level = host.level
        reposition()
        panel.orderFrontRegardless()
    }

    public func hide() {
        stopFollowingHost()
        host = nil
        panel.orderOut(nil)
    }

    private func reposition() {
        guard let host else { return }
        let size = hosting.fittingSize
        let visible = (host.screen ?? NSScreen.main)?.visibleFrame ?? host.frame
        panel.setFrame(Self.frame(size: size, beside: host.frame, preferring: side, in: visible), display: true)
    }

    public static func frame(size: CGSize, beside host: NSRect, preferring side: Side, in visibleFrame: NSRect) -> NSRect {
        let rightX = host.maxX + gap
        let leftX = host.minX - gap - size.width
        let fitsRight = rightX + size.width <= visibleFrame.maxX
        let fitsLeft = leftX >= visibleFrame.minX
        let x = switch side {
        case .right: fitsRight || !fitsLeft ? rightX : leftX
        case .left: fitsLeft || !fitsRight ? leftX : rightX
        }
        let y = max(visibleFrame.minY, host.maxY - size.height)
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    private func followHost() {
        guard let host else { return }
        let center = NotificationCenter.default
        let moved = [NSWindow.didResizeNotification, NSWindow.didMoveNotification].map { name in
            center.addObserver(forName: name, object: host, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reposition() }
            }
        }
        // Posted when the window is ordered out, too: a panel that closes takes this one with it.
        let occlusion = center.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: host, queue: .main) { [weak self, weak host] _ in
            MainActor.assumeIsolated {
                guard host?.isVisible != true else { return }
                self?.hide()
            }
        }
        hostObservers = moved + [occlusion]
    }

    private func stopFollowingHost() {
        for observer in hostObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        hostObservers = []
    }
}
