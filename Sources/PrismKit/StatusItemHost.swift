import AppKit
import Observation

/// Owns one status item per enabled tool.
///
/// There is deliberately no icon for the app itself: a Prism icon competing with the tools' own icons would be a
/// second door to the same room. Every tool icon carries the way back to Prism instead, in its right-click menu.
///
/// AppKit persists each item's position and visibility against its `autosaveName`, so a tool keeps its spot in the
/// menu bar across launches, and macOS's own ⌘-drag reordering works per icon.
@MainActor
public final class StatusItemHost: NSObject {
    private let settings: ShellSettings
    private var items: [ToolID: NSStatusItem] = [:]
    private var ticks: [ToolID: NSImage?] = [:]
    /// Shown only when no tool has its own icon. Without it, "only in the panel" for every tool would leave no way
    /// into the panel at all.
    private var fallbackItem: NSStatusItem?

    public var onFallbackClick: ((NSStatusBarButton) -> Void)?
    public var onToolClick: ((ToolID, NSStatusBarButton) -> Void)?
    /// Right-click on a tool's icon: the menu that carries the way back to Prism itself.
    public var onToolMenu: ((ToolID, NSStatusBarButton) -> Void)?

    public init(settings: ShellSettings) {
        self.settings = settings
        super.init()
    }

    /// Rebuilds the menu bar to match the current settings. Cheap enough to call on any change.
    public func sync(with registrations: [ToolRegistration]) {
        let visibleTools = registrations.filter {
            settings.isEnabled($0.id) && settings.placement(of: $0.id) == .ownIcon
        }

        // Drop items whose tool was turned off or moved into the hub.
        let keep = Set(visibleTools.map(\.id))
        for (id, item) in items where !keep.contains(id) {
            NSStatusBar.system.removeStatusItem(item)
            items[id] = nil
            ticks[id] = nil
        }

        syncFallback(needed: visibleTools.isEmpty, registrations: registrations)

        for registration in visibleTools where items[registration.id] == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            // The autosave name is the tool id, so the position survives both relaunches and layout changes.
            item.autosaveName = NSStatusItem.AutosaveName("prism.tool." + registration.id.rawValue)
            if let button = item.button {
                button.target = self
                button.action = #selector(toolItemClicked(_:))
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
                button.imagePosition = .imageOnly
                button.toolTip = registration.tool.title
            }
            item.isVisible = true
            items[registration.id] = item
        }
        refreshImages(registrations)
    }

    /// One small Prism icon, present only when it is the only way in.
    private func syncFallback(needed: Bool, registrations: [ToolRegistration]) {
        if needed, fallbackItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.autosaveName = NSStatusItem.AutosaveName("prism.fallback")
            if let button = item.button {
                button.target = self
                button.action = #selector(fallbackClicked(_:))
                button.image = FallbackIcon.image
                button.imagePosition = .imageOnly
                button.toolTip = Strings.appName
            }
            item.isVisible = true
            fallbackItem = item
        } else if !needed, let fallbackItem {
            NSStatusBar.system.removeStatusItem(fallbackItem)
            self.fallbackItem = nil
        }
    }

    @objc private func fallbackClicked(_ sender: NSStatusBarButton) {
        onFallbackClick?(sender)
    }

    /// The button for a tool's icon, for opening a panel that has to hang from it.
    public func button(of id: ToolID?) -> NSStatusBarButton? {
        guard let id else { return nil }
        return items[id]?.button
    }

    /// Redraws only the icons whose tool returned something new, so an idle app does not repaint the menu bar.
    public func refreshImages(_ registrations: [ToolRegistration]) {
        for registration in registrations {
            guard let item = items[registration.id], let button = item.button else { continue }
            let image = registration.tool.statusItemImage()
            guard image != ticks[registration.id] else { continue }
            ticks[registration.id] = image
            button.image = image
        }
    }

    @objc private func toolItemClicked(_ sender: NSStatusBarButton) {
        // Never xcrun: the sender's own item is the one that identifies its tool.
        guard let id = items.first(where: { $0.value.button === sender })?.key else { return }
        let isRightClick = NSApp.currentEvent?.type == .rightMouseUp
            || NSApp.currentEvent?.modifierFlags.contains(.control) == true
        if isRightClick {
            onToolMenu?(id, sender)
        } else {
            onToolClick?(id, sender)
        }
    }
}

/// The last-resort menu bar entry: the app's own mark, used only when every tool is inside the panel.
@MainActor
enum FallbackIcon {
    static var image: NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            NSColor.black.setStroke()
            NSColor.black.setFill()
            // A prism with a beam going in and three rays coming out.
            let beam = NSBezierPath()
            beam.move(to: NSPoint(x: 0.5, y: rect.midY))
            beam.line(to: NSPoint(x: 6.0, y: rect.midY))
            beam.lineWidth = 1.5
            beam.lineCapStyle = .round
            beam.stroke()

            let prism = NSBezierPath()
            prism.move(to: NSPoint(x: 9.0, y: rect.maxY - 1.2))
            prism.line(to: NSPoint(x: 14.2, y: rect.minY + 1.6))
            prism.line(to: NSPoint(x: 3.8, y: rect.minY + 1.6))
            prism.close()
            prism.lineWidth = 1.4
            prism.lineJoinStyle = .round
            prism.stroke()

            for offset in [-3.2, 0.0, 3.2] {
                let ray = NSBezierPath()
                ray.move(to: NSPoint(x: 10.4, y: rect.midY))
                ray.line(to: NSPoint(x: 17.5, y: rect.midY + offset))
                ray.lineWidth = 1.2
                ray.lineCapStyle = .round
                ray.stroke()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = Strings.appName
        return image
    }
}
