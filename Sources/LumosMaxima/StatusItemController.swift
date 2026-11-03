import AppKit
import Observation

/// The menu bar sun. It owns the status item, the popover-style panel and the pet window, and keeps their
/// contents in step with the model.
@MainActor
final class StatusItemController: NSObject {
    static let panelAnchorWidth: CGFloat = 26

    private let model: AppModel
    private let statusItem: NSStatusItem
    private let panel: PanelController
    private let pet: PetWindowController
    private let settings: SettingsWindowController

    init(model: AppModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let actions = PanelActions(
            toggle: { model.toggle() },
            setLength: { model.setLength($0) },
            setKeepsDisplayAwake: { model.setKeepsDisplayAwake($0) },
            setKeepsAwakeWithLidClosed: { length in
                Task { await model.setKeepsAwakeWithLidClosed(length) }
            },
            showSettings: { SettingsWindowController.shared(for: model).show() },
            quit: {
                model.stop()
                NSApp.terminate(nil)
            }
        )
        settings = SettingsWindowController.shared(for: model)
        panel = PanelController(model: model, actions: actions)
        pet = PetWindowController(model: model)
        super.init()

        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(togglePanel)
            // A right click opens the menu at the same moment as the left click that opens the panel, so only the
            // left button is wired here; the menu is reached from the panel and from the shortcut.
            button.sendAction(on: [.leftMouseUp])
        }
        panel.onVisibilityChange = { [weak self] visible in
            self?.statusItem.button?.highlight(visible)
            if visible { self?.model.uiTick() }
        }
        observeModel()
        model.petVisible = false
        if model.preferences.showsPet {
            pet.setVisible(true)
        }
    }

    #if DEBUG
    func showPanelForDebug() {
        guard let button = statusItem.button else { return }
        panel.show(below: button)
    }

    var panelWindowForDebug: NSWindow? { panel.windowForDebug }
    #endif

    /// Called every second while a session runs; cheap when nothing needs to change.
    func tick() {
        model.backgroundTick()
        if panel.isShown || pet.isVisible {
            model.uiTick()
        }
    }

    @objc private func togglePanel() {
        guard let button = statusItem.button else { return }
        panel.toggle(below: button)
    }

    /// Right click menu, also reachable from a control click on the status item.
    func showMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let toggle = NSMenuItem(
            title: model.isAwake ? Strings.stop : Strings.keepAwake,
            action: #selector(toggleSession),
            keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())
        let showPet = NSMenuItem(title: Strings.petLabel, action: #selector(togglePet), keyEquivalent: "")
        showPet.target = self
        showPet.state = model.preferences.showsPet ? .on : .off
        menu.addItem(showPet)
        let showTime = NSMenuItem(title: Strings.menuBarTime, action: #selector(toggleTime), keyEquivalent: "")
        showTime.target = self
        showTime.state = model.preferences.showsTimeInMenuBar ? .on : .off
        menu.addItem(showTime)
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: Strings.settings, action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        let quit = NSMenuItem(title: Strings.quit, action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        // Attaching a menu to the item would replace every later left click with it, so the menu is only popped up.
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func toggleSession() {
        model.toggle()
    }

    @objc private func togglePet() {
        model.preferences.showsPet.toggle()
    }

    @objc private func toggleTime() {
        model.preferences.showsTimeInMenuBar.toggle()
    }

    @objc private func openSettings() {
        settings.show()
    }

    @objc private func quitApp() {
        model.stop()
        NSApp.terminate(nil)
    }

    private func observeModel() {
        withObservationTracking {
            updateStatusItem()
            syncPet()
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeModel() }
        }
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = MenuBarIcon.image(model.menuBarState)
        button.setAccessibilityLabel(model.menuBarState.accessibilityText)
    }

    private func syncPet() {
        let shouldShow = model.preferences.showsPet
        if shouldShow != pet.isVisible {
            pet.setVisible(shouldShow)
        }
    }
}
