import AppKit
import Observation
import PrismKit
import SwiftUI

/// The awake tool as the shell sees it: one public type over everything that used to be the whole app.
///
/// The internals (`AppModel`, `SessionEngine`, `LidControl`, the pet window) are unchanged and stay internal to this
/// module. The shell only ever touches this class, which is what keeps the two tools from growing into each other.
@MainActor
public final class AwakeTool: Tool, MenuBarPresenter {
    public static let id = ToolID("awake")

    private let model = AppModel()
    private let panel: PanelController
    private let quickPanel: QuickPanelController
    private let pet: PetWindowController
    private let ticker = Ticker()
    private var started = false
    /// The image handed out last time, so the shell only repaints the menu bar when something actually changed.
    private var lastImage: NSImage?

    public init() {
        let actions = PanelActions(
            toggle: { [model] in model.toggle() },
            setLength: { [model] in model.setLength($0) },
            setKeepsDisplayAwake: { [model] in model.setKeepsDisplayAwake($0) },
            setKeepsAwakeWithLidClosed: { [model] enabled in
                Task { await model.setKeepsAwakeWithLidClosed(enabled) }
            },
            confirmLidChange: { [model] in LidPrompter.presentLidPrompt(model: model) },
            showSettings: {},
            quit: {}
        )
        panel = PanelController(model: model, actions: actions)
        quickPanel = QuickPanelController(model: model)
        pet = PetWindowController(model: model)
        pet.onClick = { [weak self] frame, screen in
            self?.quickPanel.toggle(above: frame, on: screen)
        }
        pet.onDoubleClick = {
            NotificationCenter.default.post(name: PrismNotifications.openSettings, object: nil)
        }
    }

    public var title: String { "LumosMaxima" }
    public var symbolName: String { model.isAwake ? "sun.max.fill" : "sun.min" }

    public var summary: String {
        guard model.isAwake else { return AwakeStrings.sleeping }
        guard let remaining = model.remaining else { return AwakeStrings.awake }
        return TimeText.countdown(remaining)
    }

    public func start() {
        guard !started else { return }
        started = true
        model.launch()
        model.preferences.showsPet = true
        pet.setVisible(true)
        ticker.start(every: 1) { [weak self] in self?.tick() }
    }

    public func stop() {
        guard started else { return }
        started = false
        ticker.stop()
        model.stop()
        pet.setVisible(false)
        quickPanel.hide()
        model.repairOnQuit()
    }

    public func statusItemImage() -> NSImage? {
        let image = MenuBarIcon.image(model.menuBarState)
        guard image !== lastImage else { return lastImage }
        lastImage = image
        return image
    }

    public func quickPanelView() -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 0) {
                Text(summary)
                    .font(.system(size: 12))
                Button(AwakeStrings.keepAwake) { [model] in model.toggle() }
            }
            .padding(12)
        )
    }

    public func settingsView() -> AnyView? {
        AnyView(AwakeSettingsView(model: model))
    }

    /// The pet's own page, reachable from the panel's footer rather than from the app's settings list.
    public var petSettingsView: AnyView {
        AnyView(PetSettingsView(model: model))
    }

    /// The panel and the hub both need the same closures; one builder keeps them from drifting apart.
    private func makeActions() -> PanelActions {
        PanelActions(
            toggle: { [model] in model.toggle() },
            setLength: { [model] in model.setLength($0) },
            setKeepsDisplayAwake: { [model] in model.setKeepsDisplayAwake($0) },
            setKeepsAwakeWithLidClosed: { [model] enabled in
                Task { await model.setKeepsAwakeWithLidClosed(enabled) }
            },
            confirmLidChange: { [model] in LidPrompter.presentLidPrompt(model: model) },
            showSettings: { NotificationCenter.default.post(name: PrismNotifications.openSettings, object: nil) },
            quit: { NSApp.terminate(nil) }
        )
    }

    /// The tool's own controls in the hub: the same panel the menu bar icon opens.
    public func hubView() -> AnyView {
        AnyView(
            LivePanelView(model: model, layout: PanelLayout(), actions: makeActions(), onHeightChange: { _ in })
        )
    }

    /// Opens the full panel below a menu bar item: what a click on the tool's own icon does.
    public func showPanel(below button: NSStatusBarButton) {
        panel.toggle(below: button)
    }

    #if DEBUG
    /// Starts a session the way the panel does, so the power assertion can be checked from a script.
    public func startForDebug() {
        model.start(length: .forever)
    }
    #endif

    private func tick() {
        model.backgroundTick()
        if panel.isShown || pet.isVisible {
            model.uiTick()
        }
    }
}
