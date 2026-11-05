import AppKit
import Observation
import PrismKit
import SwiftUI

/// The app: it knows the tools, owns the menu bar items and the two panels, and routes clicks.
///
/// Only one panel is open at a time: a click on a tool's icon opens its quick panel, and every way into the hub
/// closes the quick panel first.
@MainActor
final class ToolboxApp {
    let shell: ShellSettings
    let registrations: [ToolRegistration]
    private let statusItems: StatusItemHost
    private let hub: HubPanelController
    private let quick = QuickPanelController()
    private let ticker = Ticker()
    private var started: Set<ToolID> = []
    /// The icon the quick panel hangs from. A tool can have several, and a click on another one moves the panel.
    private weak var quickAnchor: NSStatusBarButton?

    init(registrations: [ToolRegistration], shell: ShellSettings) {
        self.registrations = registrations
        self.shell = shell
        statusItems = StatusItemHost(settings: shell)
        hub = HubPanelController(shell: shell, registrations: registrations)
        configure()
    }

    func launch() {
        syncTools()
        statusItems.sync(with: registrations)
        ticker.start(every: 1) { [weak self] in
            guard let self else { return }
            statusItems.sync(with: registrations)
            hub.refreshIfVisible()
            quick.refreshIfVisible()
        }
    }

    func setToolEnabled(_ id: ToolID, _ isOn: Bool) {
        shell.setEnabled(isOn, for: id)
        syncTools()
        statusItems.sync(with: registrations)
    }

    func setPlacement(_ placement: MenuBarPlacement, for id: ToolID) {
        shell.setPlacement(placement, for: id)
        statusItems.sync(with: registrations)
    }

    /// The shortcut: the hub under the pointer, on the tab it showed last.
    func toggleHub() {
        if hub.isShown {
            hub.hide()
        } else {
            quick.hide()
            hub.show(tab: nil, at: NSEvent.mouseLocation)
        }
    }

    func terminate() {
        for registration in registrations where started.contains(registration.id) {
            registration.tool.stop()
        }
        ticker.stop()
    }

    private func configure() {
        statusItems.onToolClick = { [weak self] id, button in
            self?.toggleQuickPanel(for: id, below: button)
        }
        statusItems.onToolMenu = { [weak self] id, button in
            self?.showToolMenu(for: id, below: button)
        }
        statusItems.onFallbackClick = { [weak self] button in
            guard let self else { return }
            if hub.isShown {
                hub.hide()
            } else {
                quick.hide()
                hub.show(tab: nil, below: button)
            }
        }
        quick.onOpenHub = { [weak self] id in
            self?.openHub(on: id, below: self?.quickAnchor)
        }
        hub.onSetEnabled = { [weak self] id, isOn in
            self?.setToolEnabled(id, isOn)
        }
        hub.onSetPlacement = { [weak self] id, placement in
            self?.setPlacement(placement, for: id)
        }
    }

    private func toggleQuickPanel(for id: ToolID, below button: NSStatusBarButton) {
        if quick.shownTool == id, quickAnchor === button {
            quick.hide()
            return
        }
        guard let registration = registrations.first(where: { $0.id == id }) else { return }
        hub.hide()
        quick.show(registration, below: button)
        quickAnchor = button
    }

    /// The hub on one tool's tab, hanging from the given icon, or else from one of the tool's icons.
    private func openHub(on id: ToolID, below button: NSStatusBarButton?) {
        quick.hide()
        if let button = button ?? statusItems.firstButton(of: id) {
            hub.show(tab: .tool(id), below: button)
        } else {
            hub.show(tab: .tool(id), at: NSEvent.mouseLocation)
        }
    }

    private func syncTools() {
        for registration in registrations {
            let shouldRun = shell.isEnabled(registration.id)
            let isRunning = started.contains(registration.id)
            switch (shouldRun, isRunning) {
            case (true, false):
                registration.tool.start()
                started.insert(registration.id)
            case (false, true):
                registration.tool.stop()
                started.remove(registration.id)
            default:
                break
            }
        }
    }

    /// Right-click on a tool's icon: the way to Prism itself, which has no icon of its own.
    private func showToolMenu(for id: ToolID, below button: NSStatusBarButton) {
        quick.hide()
        hub.hide()
        let menu = NSMenu()
        menu.autoenablesItems = false

        let open = NSMenuItem(title: Strings.openHub, action: #selector(openHubFromMenu(_:)), keyEquivalent: "")
        open.target = self
        open.representedObject = MenuTarget(id: id, button: button)
        menu.addItem(open)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: Strings.quit, action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func openHubFromMenu(_ sender: NSMenuItem) {
        guard let target = sender.representedObject as? MenuTarget else { return }
        openHub(on: target.id, below: target.button)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private struct MenuTarget {
        let id: ToolID
        let button: NSStatusBarButton
    }

    #if DEBUG
    /// Opens each panel in turn at a fixed spot and screenshots it: every hub tab, then every quick panel.
    func capturePanels(to directory: String) async -> Bool {
        guard let screen = NSScreen.main else { return false }
        let frame = screen.visibleFrame
        let anchor = NSRect(x: frame.midX - HubPanelController.width / 2, y: frame.maxY, width: 1, height: 1)
        var ok = true
        let tabs = registrations.map { (HubTab.tool($0.id), $0.id.rawValue) } + [(HubTab.general, "general")]
        for (tab, name) in tabs {
            hub.show(tab: tab, anchoredAt: anchor, on: screen)
            ok = await DebugCapture.window(hub.window, to: "\(directory)/hub-\(name).png") && ok
        }
        hub.hide()
        for registration in registrations {
            quick.show(registration, anchoredAt: anchor, on: screen)
            ok = await DebugCapture.window(quick.window, to: "\(directory)/quick-\(registration.id.rawValue).png") && ok
        }
        quick.hide()
        return ok
    }
    #endif
}
