import AppKit
import Observation

/// Owns every status item in the app: the hub's own, plus one per tool that asked for its own icon.
///
/// One `NSStatusItem` per tool — rather than one icon that changes meaning — is what lets a tool be turned "separate"
/// or "merged" independently. AppKit persists each item's position and visibility against its `autosaveName`, so a
/// tool keeps its spot in the menu bar across launches, and macOS's own ⌘-drag reordering works per icon.
@MainActor
public final class StatusItemHost: NSObject {
    private let settings: ShellSettings
    private var items: [ToolID: NSStatusItem] = [:]
    private var hubItem: NSStatusItem?
    private var ticks: [ToolID: NSImage?] = [:]

    public var onHubClick: ((NSStatusBarButton) -> Void)?
    public var onToolClick: ((ToolID, NSStatusBarButton) -> Void)?
    /// Called for tools with their own icon when the person right-clicks it.
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
        let needsHub = settings.hubPlacement == .ownIcon || visibleTools.isEmpty

        // Drop items whose tool was turned off or moved into the hub.
        let keep = Set(visibleTools.map(\.id))
        for (id, item) in items where !keep.contains(id) {
            NSStatusBar.system.removeStatusItem(item)
            items[id] = nil
            ticks[id] = nil
        }

        if needsHub {
            hubItem = hubItem ?? makeHubItem()
        } else if let hubItem {
            NSStatusBar.system.removeStatusItem(hubItem)
            self.hubItem = nil
        }

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

    public func hubButton() -> NSStatusBarButton? { hubItem?.button }

    private func makeHubItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = NSStatusItem.AutosaveName("prism.hub")
        if let button = item.button {
            button.target = self
            button.action = #selector(hubClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.image = PrismIcon.hubImage()
            button.imagePosition = .imageOnly
            button.toolTip = Strings.appName
        }
        item.isVisible = true
        return item
    }

    @objc private func hubClicked(_ sender: NSStatusBarButton) {
        onHubClick?(sender)
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

/// The hub's own icon: a prism splitting a beam, which is what "one app, several tools" is meant to look like.
@MainActor
public enum PrismIcon {
    public static func hubImage() -> NSImage {
        let size = NSSize(width: 19, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setStroke()
            NSColor.black.setFill()
            // A beam coming in from the left.
            let beam = NSBezierPath()
            beam.move(to: NSPoint(x: 0.6, y: rect.midY))
            beam.line(to: NSPoint(x: 6.2, y: rect.midY))
            beam.lineWidth = 1.6
            beam.lineCapStyle = .round
            beam.stroke()
            // The prism.
            let prism = NSBezierPath()
            prism.move(to: NSPoint(x: 9.4, y: rect.maxY - 1.4))
            prism.line(to: NSPoint(x: 14.6, y: rect.minY + 1.8))
            prism.line(to: NSPoint(x: 4.2, y: rect.minY + 1.8))
            prism.close()
            prism.lineWidth = 1.5
            prism.lineJoinStyle = .round
            prism.stroke()
            // Three rays fanning out of it.
            let fan = NSBezierPath()
            for (index, offset) in [-3.4, 0.0, 3.4].enumerated() {
                let ray = NSBezierPath()
                ray.move(to: NSPoint(x: 10.6, y: rect.midY))
                ray.line(to: NSPoint(x: 18.0, y: rect.midY + offset))
                ray.lineWidth = index == 1 ? 1.6 : 1.2
                ray.lineCapStyle = .round
                fan.append(ray)
            }
            fan.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = Strings.appName
        return image
    }
}
