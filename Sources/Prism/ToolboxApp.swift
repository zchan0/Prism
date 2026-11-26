import AppKit
import Observation
import PrismKit
import SwiftUI

/// The app: it knows the tools, owns the menu bar items, the tools' panels and the Prism window, and routes clicks.
///
/// A click on a tool's icon opens that tool's panel. Every way into the Prism window closes the panel first: the
/// panel's gear and the icon's right-click menu open the tool's page, and the Prism icon, opening Prism again and a
/// new install's first launch open the page shown last.
@MainActor
final class ToolboxApp {
    let shell: ShellSettings
    let registrations: [ToolRegistration]
    let updater: Updater
    private let statusItems: StatusItemHost
    private let prismWindow: PrismWindowController
    private let quick = QuickPanelController()
    private let ticker = Ticker()
    private var started: Set<ToolID> = []
    /// The icon the panel hangs from. A tool can have several, and a click on another one moves the panel.
    private weak var quickAnchor: NSStatusBarButton?

    init(registrations: [ToolRegistration], shell: ShellSettings) {
        self.registrations = registrations
        self.shell = shell
        let updater = Updater()
        self.updater = updater
        statusItems = StatusItemHost(settings: shell)
        prismWindow = PrismWindowController(shell: shell, registrations: registrations, updater: updater)
        configure()
    }

    /// `welcomes` opens the Prism window when this is a new install's first launch.
    func launch(welcomes: Bool) {
        applyAppearance()
        syncTools()
        statusItems.sync(with: registrations)
        ticker.start(every: 1) { [weak self] in
            guard let self else { return }
            statusItems.sync(with: registrations)
            prismWindow.refreshIfVisible()
            quick.refreshIfVisible()
            updater.tick()
        }
        if welcomes, shell.isFirstLaunch {
            shell.markLaunched()
            openWindow(nil)
        }
        updater.start()
        if updater.reopensWindow {
            openWindow(.general)
        }
    }

    /// Nothing a relaunch would interrupt: no window or panel of Prism's on screen, and no tool busy.
    private var isIdle: Bool {
        !prismWindow.window.isVisible
            && !quick.isShown
            // The menu bar icons are windows too.
            && !NSApp.windows.contains { $0.isVisible && $0.level != .statusBar }
            && blockingTools.isEmpty
    }

    private var startedTools: [Tool] {
        registrations.filter { started.contains($0.id) }.map(\.tool)
    }

    private var blockingTools: [String] {
        registrations.filter { shell.isEnabled($0.id) && $0.tool.blocksRelaunch }.map(\.tool.title)
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

    func setAppearance(_ appearance: ShellSettings.Appearance) {
        shell.setAppearance(appearance)
        applyAppearance()
    }

    /// Every panel and window follows the app's appearance, so they all change at once.
    private func applyAppearance() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["PRISM_APPEARANCE"] != nil { return }
        #endif
        NSApp.appearance = switch shell.appearance {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    /// Nil opens the page shown last.
    func openWindow(_ page: WindowPage?) {
        quick.hide()
        prismWindow.show(page)
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
        statusItems.onFallbackClick = { [weak self] _ in
            self?.openWindow(nil)
        }
        quick.onOpenSettings = { [weak self] id in
            self?.openWindow(.tool(id))
        }
        ToolPageRoute.open = { [weak self] id in
            self?.openWindow(.tool(id))
        }
        prismWindow.onSetEnabled = { [weak self] id, isOn in
            self?.setToolEnabled(id, isOn)
        }
        prismWindow.onSetPlacement = { [weak self] id, placement in
            self?.setPlacement(placement, for: id)
        }
        prismWindow.onSetAppearance = { [weak self] appearance in
            self?.setAppearance(appearance)
        }
        updater.isIdle = { [weak self] in
            self?.isIdle ?? false
        }
        updater.blockingTools = { [weak self] in
            self?.blockingTools ?? []
        }
        updater.prepareForRelaunch = { [weak self] in
            guard let self else { return RelaunchHold() }
            return RelaunchHold.merged(startedTools.compactMap { $0.prepareForRelaunch() })
        }
        updater.relaunchCancelled = { [weak self] in
            self?.startedTools.forEach { $0.relaunchCancelled() }
        }
        quick.updater = updater
        quick.onOpenGeneral = { [weak self] in
            self?.openWindow(.general)
        }
    }

    private func toggleQuickPanel(for id: ToolID, below button: NSStatusBarButton) {
        if quick.shownTool == id, quickAnchor === button {
            quick.hide()
            return
        }
        guard let registration = registrations.first(where: { $0.id == id }) else { return }
        quick.show(registration, below: button)
        quickAnchor = button
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

    /// Right-click on a tool's icon: the way to the Prism window without opening the panel first.
    private func showToolMenu(for id: ToolID, below button: NSStatusBarButton) {
        quick.hide()
        let menu = NSMenu()
        menu.autoenablesItems = false

        let settings = NSMenuItem(title: Strings.prismSettings, action: #selector(openSettingsFromMenu(_:)), keyEquivalent: "")
        settings.target = self
        settings.representedObject = id.rawValue
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: Strings.quit, action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func openSettingsFromMenu(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String else { return }
        openWindow(.tool(ToolID(rawValue: rawValue)))
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    #if DEBUG
    /// Opens each tool's panel in turn at a fixed spot and screenshots it, then every page of the Prism window,
    /// without making Prism the active app.
    func capture(to directory: String) async -> Bool {
        guard let screen = NSScreen.main else { return false }
        var ok = true
        for registration in registrations {
            ok = await capturePanel(of: registration.id, on: screen, to: "\(directory)/popover-\(registration.id.rawValue).png") && ok
        }
        quick.hide()
        let pages = registrations.map { (WindowPage.tool($0.id), $0.id.rawValue) } + [(WindowPage.general, "general")]
        for (page, name) in pages {
            prismWindow.prepareForCapture(page)
            ok = await DebugCapture.window(prismWindow.window, to: "\(directory)/window-\(name).png") && ok
        }
        prismWindow.window.orderOut(nil)
        return ok
    }

    /// One tool's panel at a fixed spot, without its ⌘, so the key still reaches the app in front.
    func capturePanel(of id: ToolID, on screen: NSScreen? = NSScreen.main, to path: String) async -> Bool {
        guard let screen, let registration = registrations.first(where: { $0.id == id }) else { return false }
        let frame = screen.visibleFrame
        let anchor = NSRect(x: frame.midX - QuickPanelController.width / 2, y: frame.maxY, width: 1, height: 1)
        quick.opensSettingsWithCommandComma = false
        quick.show(registration, anchoredAt: anchor, on: screen)
        return await DebugCapture.window(quick.window, to: path)
    }

    func hideQuickPanel() {
        quick.hide()
    }

    /// Each tool's panel, the history window `historyWindow` returns, and the Prism window on Lumos's page and on
    /// General, each over the same colorful backdrop and captured from the screen, so the glass shows what it shows
    /// in use. General is scrolled to its end.
    func captureLooks(to directory: String, historyWindow: () -> NSWindow?) async -> Bool {
        guard let screen = NSScreen.main else { return false }
        let backdrop = DebugBackdrop()
        var ok = true
        let visible = screen.visibleFrame
        // Well below the menu bar, which no window can cover, so it stays out of the screenshots.
        let anchor = NSRect(x: visible.midX - QuickPanelController.width / 2, y: visible.midY + 260, width: 1, height: 1)
        quick.opensSettingsWithCommandComma = false
        for registration in registrations {
            quick.show(registration, anchoredAt: anchor, on: screen)
            try? await Task.sleep(for: .seconds(0.8))
            let frame = quick.window.frame
            backdrop.cover(frame)
            try? await Task.sleep(for: .seconds(1))
            ok = DebugCapture.screen(around: frame, to: "\(directory)/panel-\(registration.id.rawValue).png") && ok
        }
        quick.hide()
        if let history = historyWindow() {
            history.center()
            history.orderFrontRegardless()
            try? await Task.sleep(for: .seconds(0.5))
            backdrop.cover(history.frame)
            try? await Task.sleep(for: .seconds(1))
            ok = DebugCapture.screen(around: history.frame, to: "\(directory)/history.png") && ok
            history.orderOut(nil)
        }
        var pages: [(WindowPage, String)] = [(.general, "window-general")]
        if let lumos = registrations.first(where: { $0.id.rawValue == "lumos" }) {
            pages.insert((.tool(lumos.id), "window-lumos"), at: 0)
        }
        for (page, name) in pages {
            prismWindow.prepareForCapture(page)
            backdrop.cover(prismWindow.window.frame)
            prismWindow.window.orderFrontRegardless()
            try? await Task.sleep(for: .seconds(1))
            if page == .general {
                DebugCapture.scrollToEnd(in: prismWindow.window)
                try? await Task.sleep(for: .seconds(0.5))
            }
            ok = DebugCapture.screen(around: prismWindow.window.frame, to: "\(directory)/\(name).png") && ok
        }
        prismWindow.window.orderOut(nil)
        backdrop.hide()
        return ok
    }

    func captureGeneralPage(to path: String) async -> Bool {
        prismWindow.prepareForCapture(.general)
        if ProcessInfo.processInfo.environment["PRISM_SHOW_WHATS_NEW"] == "1" {
            // The popover is a window of its own, so the screen around the Prism window is captured instead.
            prismWindow.window.orderFrontRegardless()
            try? await Task.sleep(for: .seconds(1.5))
            let ok = DebugCapture.screen(around: prismWindow.window.frame, to: path)
            prismWindow.window.orderOut(nil)
            return ok
        }
        let ok = await DebugCapture.window(prismWindow.window, to: path)
        prismWindow.window.orderOut(nil)
        return ok
    }

    func capturePage(of id: ToolID, to path: String) async -> Bool {
        prismWindow.prepareForCapture(.tool(id))
        let ok = await DebugCapture.window(prismWindow.window, to: path)
        prismWindow.window.orderOut(nil)
        return ok
    }
    #endif
}
