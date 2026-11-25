import AppKit
import Observation
import PrismKit
import SwiftUI

/// The Lumos tool as the shell sees it. `AppModel`, `SessionEngine` and `LidControl` stay internal to this module.
@MainActor
public final class LumosTool: Tool {
    public static let id = ToolID("lumos")

    private let model = AppModel()
    private let ticker = Ticker()
    private let glyph = MenuBarGlyph.Cache()
    private var started = false

    public init() {}

    public var title: String { "Lumos" }
    public var tagline: String { LumosStrings.tagline }
    public var symbolName: String { model.menuBarState.symbolName }
    public var symbolPrimaryLayerOnly: Bool { !model.menuBarState.isLit }
    public var tint: ToolTint { Palette.lumos }

    public var summary: String {
        Self.summary(isAwake: model.isAwake, remaining: model.remaining)
    }

    /// "29 min left", "Awake" until stopped, or "Not keeping awake".
    static func summary(isAwake: Bool, remaining: TimeInterval?) -> String {
        guard isAwake else { return LumosStrings.notKeepingAwake }
        return remaining.map { LumosStrings.inTime(TimeText.remaining($0)) } ?? LumosStrings.awake
    }

    public func start() {
        guard !started else { return }
        started = true
        model.launch()
        ticker.start(every: 1) { [weak self] in self?.model.uiTick() }
    }

    public func stop() {
        guard started else { return }
        started = false
        ticker.stop()
        model.stop()
        model.repairOnQuit()
    }

    public func statusIcons() -> [StatusIcon] {
        let state = model.menuBarState
        return [StatusIcon(id: "wand", image: glyph.image(
            symbol: state.symbolName,
            primaryLayerOnly: !state.isLit,
            text: state.timeText,
            accessibilityDescription: "\(title): \(state.accessibilityText)"
        ))]
    }

    public func controlsView() -> AnyView {
        AnyView(LiveControlsView(model: model, actions: ControlsActions(
            toggle: { [model] in model.toggle() },
            setLength: { [model] in model.setLength($0) },
            setKeepsDisplayAwake: { [model] in model.setKeepsDisplayAwake($0) },
            setKeepsAwakeWithLidClosed: { [model] enabled in
                Task { await model.setKeepsAwakeWithLidClosed(enabled) }
            },
            confirmLidChange: { [model] in LidPrompter.presentLidPrompt(model: model) }
        )))
    }

    public func settingsView() -> AnyView? {
        AnyView(LumosSettingsView(preferences: model.preferences))
    }

    public func menuBarSettings() -> MenuBarSettings? {
        MenuBarSettings(rows: AnyView(LumosMenuBarSettingsView(preferences: model.preferences)))
    }

    #if DEBUG
    /// Starts a 30 minute session without remembering the length, so a capture shows a countdown and a script can
    /// check the power assertion.
    public func startForDebug() {
        model.engine.start(length: .thirtyMinutes, keepsDisplayAwake: model.preferences.keepsDisplayAwake)
    }

    /// Shows the note under the Screen and Lid closed buttons, on battery, together with an error.
    public func showNotesForDebug(_ shows: Bool) {
        model.showsNotesForDebug = shows
    }

    /// Call before the tool starts.
    public func leaveLidAloneForDebug() {
        model.leavesLidAloneForDebug = true
    }
    #endif
}
