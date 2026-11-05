import AppKit
import Observation

/// Owns the status items of every enabled tool: one for each icon the tool asks for.
///
/// There is deliberately no icon for the app itself: a Prism icon competing with the tools' own icons would be a
/// second door to the same room. Every tool icon carries the way back to Prism instead, in its right-click menu.
///
/// AppKit persists each item's position and visibility against its `autosaveName`, so an icon keeps its spot in the
/// menu bar across launches, and macOS's own ⌘-drag reordering works per icon.
@MainActor
public final class StatusItemHost: NSObject {
    private struct Key: Hashable {
        let tool: ToolID
        let icon: String
    }

    private let settings: ShellSettings
    private var items: [Key: NSStatusItem] = [:]
    private var images: [Key: NSImage] = [:]
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

    /// Makes the menu bar match the settings and the icons the tools ask for. Cheap enough to call every second.
    public func sync(with registrations: [ToolRegistration]) {
        let visibleTools = registrations.filter {
            settings.isEnabled($0.id) && settings.placement(of: $0.id) == .ownIcon
        }
        syncFallback(needed: visibleTools.isEmpty)

        let wanted = visibleTools.flatMap { registration in
            registration.tool.statusIcons().map { (key: Key(tool: registration.id, icon: $0.id), image: $0.image) }
        }
        let keep = Set(wanted.map(\.key))
        for (key, item) in items where !keep.contains(key) {
            NSStatusBar.system.removeStatusItem(item)
            items[key] = nil
            images[key] = nil
        }
        // A new item goes to the left of the ones already there, so creating them right to left keeps a tool's order.
        for (key, _) in wanted.reversed() where items[key] == nil {
            items[key] = makeItem(key, title: registrations.first { $0.id == key.tool }?.tool.title ?? "")
        }
        for (key, image) in wanted where images[key] !== image {
            images[key] = image
            items[key]?.button?.image = image
        }
    }

    private func makeItem(_ key: Key, title: String) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = NSStatusItem.AutosaveName("prism.tool.\(key.tool.rawValue).\(key.icon)")
        if let button = item.button {
            button.target = self
            button.action = #selector(toolItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageOnly
            button.toolTip = title
        }
        item.isVisible = true
        return item
    }

    /// One small Prism icon, present only when it is the only way in.
    private func syncFallback(needed: Bool) {
        if needed, fallbackItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.autosaveName = NSStatusItem.AutosaveName("prism.fallback")
            if let button = item.button {
                button.target = self
                button.action = #selector(fallbackClicked(_:))
                button.image = MenuBarGlyph.image(
                    symbol: "triangle",
                    text: nil,
                    accessibilityDescription: Strings.appName
                )
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

    /// The leftmost icon of a tool, for opening the hub from somewhere that is not one of its icons.
    public func firstButton(of id: ToolID) -> NSStatusBarButton? {
        items.filter { $0.key.tool == id }
            .compactMap(\.value.button)
            .min { ($0.window?.frame.minX ?? 0) < ($1.window?.frame.minX ?? 0) }
    }

    @objc private func toolItemClicked(_ sender: NSStatusBarButton) {
        guard let id = items.first(where: { $0.value.button === sender })?.key.tool else { return }
        let isRightClick = NSApp.currentEvent?.type == .rightMouseUp
            || NSApp.currentEvent?.modifierFlags.contains(.control) == true
        if isRightClick {
            onToolMenu?(id, sender)
        } else {
            onToolClick?(id, sender)
        }
    }
}
