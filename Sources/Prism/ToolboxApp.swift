import AppKit
import Observation
import PrismKit
import SwiftUI

/// The app: it knows the tools, owns the one menu bar host and the one settings window, and routes clicks.
///
/// Everything tool-specific lives behind `ToolRegistration`, so adding a tool is a line in `AppDelegate` plus a
/// module, and no change here.
@MainActor
final class ToolboxApp {
    let shell: ShellSettings
    let registrations: [ToolRegistration]
    private let statusItems: StatusItemHost
    private let hub: HubPanelController
    private let settings: SettingsWindowController
    private let ticker = Ticker()
    private var started: Set<ToolID> = []

    init(registrations: [ToolRegistration], shell: ShellSettings) {
        self.registrations = registrations
        self.shell = shell
        statusItems = StatusItemHost(settings: shell)
        hub = HubPanelController(shell: shell, registrations: registrations)
        settings = SettingsWindowController(shell: shell, registrations: registrations)
        configure()
    }

    func launch() {
        syncTools()
        statusItems.sync(with: registrations)
        // One shared clock: each tool is asked for its menu bar image once a second, and it returns nil or an
        // unchanged image when nothing moved, so SwiftUI and AppKit do no work in the common case.
        ticker.start(every: 1) { [weak self] in
            guard let self else { return }
            statusItems.refreshImages(registrations)
            hub.refreshIfVisible()
        }
        NotificationCenter.default.addObserver(
            forName: PrismNotifications.openSettings,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.settings.show() }
        }
    }

    func setToolEnabled(_ id: ToolID, _ isOn: Bool) {
        shell.setEnabled(isOn, for: id)
        syncTools()
        statusItems.sync(with: registrations)
        hub.refresh()
    }

    func setPlacement(_ placement: MenuBarPlacement, for id: ToolID) {
        shell.setPlacement(placement, for: id)
        statusItems.sync(with: registrations)
    }

    /// The shared shortcut: opens the hub, which is the one surface that shows every tool.
    /// The shared shortcut opens the hub under the pointer: with no icon of its own, the hub has no anchor to hang
    /// from, and the pointer is where the person is looking.
    func toggleHub() {
        if hub.isShown {
            hub.hide()
        } else {
            hub.show(at: NSEvent.mouseLocation)
        }
    }

    #if DEBUG
    func settingsWindow() -> NSWindow { settings.makeWindow() }
    #endif


    private func configure() {
        statusItems.onToolClick = { [weak self] id, button in
            guard let self, let registration = registrations.first(where: { $0.id == id }) else { return }
            // A tool that has its own panel opens it; otherwise the hub is its panel.
            if let presenter = registration.tool as? MenuBarPresenter {
                presenter.showPanel(below: button)
            } else {
                hub.toggle(below: button)
            }
        }
        statusItems.onFallbackClick = { [weak self] button in
            self?.hub.toggle(below: button)
        }
        statusItems.onToolMenu = { [weak self] id, button in
            self?.showToolMenu(for: id, below: button)
        }
        hub.onOpenSettings = { [weak self] in self?.settings.show() }
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

    /// Every tool's icon carries the way back to Prism: the hub, the settings, and quitting. Without a Prism icon of
    /// its own, this menu is what keeps the app as a whole reachable from any of its tools.
    private func showToolMenu(for id: ToolID, below button: NSStatusBarButton) {
        let menu = NSMenu()
        menu.autoenablesItems = false

        if let tool = registrations.first(where: { $0.id == id })?.tool {
            let open = NSMenuItem(title: Strings.openTool(tool.title), action: #selector(openToolPanel(_:)), keyEquivalent: "")
            open.target = self
            open.representedObject = id.rawValue
            menu.addItem(open)
        }

        let hubItem = NSMenuItem(title: Strings.openHub, action: #selector(openHub), keyEquivalent: "")
        hubItem.target = self
        menu.addItem(hubItem)

        let settingsItem = NSMenuItem(title: Strings.openSettings, action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: Strings.quit, action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func openSettings() {
        settings.show()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func openHub() {
        if let button = statusItems.button(of: registrations.first(where: { shell.isEnabled($0.id) })?.id) {
            hub.toggle(below: button)
        } else {
            hub.show(at: NSEvent.mouseLocation)
        }
    }

    @objc private func openToolPanel(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let button = statusItems.button(of: ToolID(raw)) else { return }
        guard let registration = registrations.first(where: { $0.id == ToolID(raw) }) else { return }
        if let presenter = registration.tool as? MenuBarPresenter {
            presenter.showPanel(below: button)
        } else {
            hub.toggle(below: button)
        }
    }

    func terminate() {
        for registration in registrations where started.contains(registration.id) {
            registration.tool.stop()
        }
        ticker.stop()
    }
}
