import AppKit
import Carbon.HIToolbox
import Observation
import PrismKit
import SwiftUI

@MainActor
@Observable
final class QuickPanelModel {
    var registration: ToolRegistration?
    var updater: Updater?
    /// Bumped on every opening, so the tool's controls are built fresh and their `onAppear` runs again.
    var opening = 0
    var revision = 0
}

/// The panel a click on a tool's menu bar icon opens: only that tool's controls, and under them the tool's name and
/// the gear that opens its page in the Prism window.
@MainActor
final class QuickPanelController {
    static let width: CGFloat = 320

    var onOpenSettings: ((ToolID) -> Void)?
    /// The gear while an update waits: it opens General instead of the tool's page.
    var onOpenGeneral: (() -> Void)?
    /// Whether ⌘, opens the shown tool's page while the panel is open. Off for screenshots, so the key still reaches
    /// the app in front.
    var opensSettingsWithCommandComma = true

    var updater: Updater? {
        get { model.updater }
        set { model.updater = newValue }
    }

    private let model = QuickPanelModel()
    private let panel: FloatingPanelController
    private(set) var settingsKey: GlobalHotKey.Registration?

    init() {
        panel = FloatingPanelController(width: Self.width, cornerRadius: 24, content: AnyView(EmptyView()))
        panel.setContent(AnyView(QuickPanelView(
            model: model,
            close: { [weak self] in self?.hide() },
            openSettings: { [weak self] id in self?.onOpenSettings?(id) },
            openGeneral: { [weak self] in self?.onOpenGeneral?() },
            onHeight: { [weak self] height in self?.panel.setContentHeight(height) }
        )))
        // Every way the panel closes goes through the controller's `hide()`, which reports it here.
        panel.onVisibilityChange = { [weak self] isShown in self?.visibilityChanged(isShown) }
    }

    var isShown: Bool { panel.isShown }
    /// The tool whose controls are on screen, or nil while the panel is closed.
    var shownTool: ToolID? { isShown ? model.registration?.id : nil }

    func show(_ registration: ToolRegistration, below button: NSStatusBarButton) {
        prepare(registration)
        panel.show(below: button)
    }

    func show(_ registration: ToolRegistration, anchoredAt rect: NSRect, on screen: NSScreen) {
        prepare(registration)
        panel.show(anchoredAt: rect, placement: .below, on: screen)
    }

    func hide() {
        panel.hide()
    }

    func refreshIfVisible() {
        guard isShown else { return }
        model.revision += 1
    }

    func visibilityChanged(_ isShown: Bool) {
        if isShown, opensSettingsWithCommandComma {
            registerSettingsKey()
        } else {
            unregisterSettingsKey()
        }
    }

    /// The panel never takes the keyboard, so ⌘, reaches it only as a hot key, held only while the panel is open.
    /// When macOS refuses it, `GlobalHotKey` logs why and the panel works without it.
    private func registerSettingsKey() {
        guard settingsKey == nil else { return }
        let result = GlobalHotKey.register(keyCode: UInt32(kVK_ANSI_Comma), modifiers: UInt32(cmdKey)) { [weak self] in
            guard let self, let id = shownTool else { return }
            onOpenSettings?(id)
        }
        if case .success(let registration) = result {
            settingsKey = registration
        }
    }

    private func unregisterSettingsKey() {
        guard let settingsKey else { return }
        GlobalHotKey.unregister(settingsKey)
        self.settingsKey = nil
    }

    #if DEBUG
    var window: NSWindow { panel.window }
    #endif

    private func prepare(_ registration: ToolRegistration) {
        model.registration = registration
        model.opening += 1
    }
}

struct QuickPanelView: View {
    let model: QuickPanelModel
    let close: @MainActor () -> Void
    let openSettings: @MainActor (ToolID) -> Void
    let openGeneral: @MainActor () -> Void
    let onHeight: @MainActor (CGFloat) -> Void

    var body: some View {
        let _ = model.revision
        VStack(spacing: 4) {
            if let registration = model.registration {
                let id = registration.id
                let tool = registration.tool
                tool.controlsView()
                    .id(model.opening)
                    .environment(\.toolPanel, ToolPanelActions(close: close, openSettings: { openSettings(id) }))
                HStack(spacing: 8) {
                    Text(tool.title)
                        .font(PanelFont.section)
                        .foregroundStyle(Color(nsColor: Palette.ink3))
                    Spacer(minLength: 8)
                    let badge = model.updater?.attentionBadge
                    PanelIconButton(symbol: "gearshape", title: Strings.toolSettings(tool.title), badge: badge) {
                        if badge != nil {
                            openGeneral()
                        } else {
                            openSettings(id)
                        }
                    }
                }
                .padding(.leading, 8)
                .frame(height: 32)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .frame(width: QuickPanelController.width)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onHeight($0) }
        // While the panel animates to a new height, the content stays on its top edge.
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
