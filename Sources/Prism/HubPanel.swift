import AppKit
import Observation
import PrismKit
import SwiftUI

enum HubTab: Hashable {
    case tool(ToolID)
    case general
}

@MainActor
@Observable
final class HubModel {
    var tab: HubTab
    /// Bumped on every opening, so each tab's content is built fresh and its `onAppear` runs again.
    var opening = 0
    /// Bumped once a second while the hub is open, so content that SwiftUI cannot observe is read again too.
    var revision = 0

    init(tab: HubTab) {
        self.tab = tab
    }
}

struct HubActions {
    var setEnabled: @MainActor (ToolID, Bool) -> Void
    var setPlacement: @MainActor (ToolID, MenuBarPlacement) -> Void
    var quit: @MainActor () -> Void
    var onHeight: @MainActor (CGFloat) -> Void
}

/// The hub: one tab per tool, each with the tool's switches, controls and settings, and a tab for Prism itself.
@MainActor
final class HubPanelController {
    static let width: CGFloat = 340

    var onSetEnabled: ((ToolID, Bool) -> Void)?
    var onSetPlacement: ((ToolID, MenuBarPlacement) -> Void)?

    private let model: HubModel
    private let loginItem = LoginItem()
    private let panel: FloatingPanelController

    init(shell: ShellSettings, registrations: [ToolRegistration]) {
        model = HubModel(tab: registrations.first.map { .tool($0.id) } ?? .general)
        panel = FloatingPanelController(width: Self.width, content: AnyView(EmptyView()))
        let actions = HubActions(
            setEnabled: { [weak self] id, isOn in self?.onSetEnabled?(id, isOn) },
            setPlacement: { [weak self] id, placement in self?.onSetPlacement?(id, placement) },
            quit: { NSApp.terminate(nil) },
            onHeight: { [weak self] height in self?.panel.setContentHeight(height) }
        )
        panel.setContent(AnyView(HubView(
            model: model,
            shell: shell,
            registrations: registrations,
            loginItem: loginItem,
            actions: actions
        )))
    }

    var isShown: Bool { panel.isShown }

    /// Opens below a menu bar item. A nil tab keeps the one the hub showed last.
    func show(tab: HubTab?, below button: NSStatusBarButton) {
        prepare(tab)
        panel.show(below: button)
    }

    /// Opens at the pointer, for the shortcut: there is no icon to hang from.
    func show(tab: HubTab?, at point: NSPoint) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main else { return }
        show(tab: tab, anchoredAt: NSRect(x: point.x, y: point.y, width: 1, height: 1), on: screen)
    }

    func show(tab: HubTab?, anchoredAt rect: NSRect, on screen: NSScreen) {
        prepare(tab)
        panel.show(anchoredAt: rect, placement: .below, on: screen)
    }

    func hide() {
        panel.hide()
    }

    func refreshIfVisible() {
        guard isShown else { return }
        model.revision += 1
    }

    #if DEBUG
    var window: NSWindow { panel.window }
    #endif

    private func prepare(_ tab: HubTab?) {
        if let tab { model.tab = tab }
        model.opening += 1
    }
}

struct HubView: View {
    let model: HubModel
    let shell: ShellSettings
    let registrations: [ToolRegistration]
    let loginItem: LoginItem
    let actions: HubActions

    var body: some View {
        let _ = model.revision
        VStack(spacing: 0) {
            tabBar
            PanelDivider()
            page
                .id(model.opening)
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 12)
        }
        .frame(width: HubPanelController.width)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { actions.onHeight($0) }
    }

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(registrations, id: \.id) { registration in
                HubTabButton(
                    symbol: registration.tool.symbolName,
                    primaryLayerOnly: registration.tool.symbolPrimaryLayerOnly,
                    title: registration.tool.title,
                    accessibilityTitle: registration.tool.title,
                    isSelected: model.tab == .tool(registration.id),
                    isDimmed: !shell.isEnabled(registration.id)
                ) {
                    model.tab = .tool(registration.id)
                }
            }
            Spacer(minLength: 6)
            Rectangle()
                .fill(Color(nsColor: Palette.hair))
                .frame(width: 1, height: 16)
            HubTabButton(
                symbol: "gearshape",
                title: nil,
                accessibilityTitle: Strings.generalTab,
                isSelected: model.tab == .general,
                isDimmed: false
            ) {
                model.tab = .general
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
    }

    @ViewBuilder
    private var page: some View {
        switch model.tab {
        case .general:
            HubGeneralPage(loginItem: loginItem, quit: actions.quit)
        case .tool(let id):
            if let registration = registrations.first(where: { $0.id == id }) {
                HubToolPage(registration: registration, shell: shell, actions: actions)
            }
        }
    }
}

/// A tool's tab: the shell's two switches on top, then what the tool draws itself.
private struct HubToolPage: View {
    let registration: ToolRegistration
    let shell: ShellSettings
    let actions: HubActions

    var body: some View {
        let id = registration.id
        let isOn = shell.isEnabled(id)
        VStack(alignment: .leading, spacing: 0) {
            PanelRow(Strings.turnedOn) {
                PanelSwitch(isOn: Binding(
                    get: { shell.isEnabled(id) },
                    set: { actions.setEnabled(id, $0) }
                ))
            }
            PanelRow(Strings.showInMenuBar) {
                PanelSwitch(isOn: Binding(
                    get: { shell.placement(of: id) == .ownIcon },
                    set: { actions.setPlacement(id, $0 ? .ownIcon : .hubOnly) }
                ))
                .disabled(!isOn)
            }
            if isOn {
                PanelDivider()
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                registration.tool.controlsView()
                if let settings = registration.tool.settingsView() {
                    PanelDivider()
                        .padding(.top, 10)
                        .padding(.bottom, 3)
                    settings
                }
            } else {
                Text(Strings.turnedOffNote)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(nsColor: Palette.ink3))
                    .padding(.top, 4)
            }
        }
    }
}

/// Prism's own tab: what used to be the settings window.
private struct HubGeneralPage: View {
    let loginItem: LoginItem
    let quit: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelRow(Strings.loginItem, note: loginNote) {
                PanelSwitch(isOn: Binding(
                    get: { loginItem.isOn },
                    set: { loginItem.setOn($0) }
                ))
                .disabled(!loginItem.isAvailable)
            }
            Text(Strings.version(Self.version))
                .font(.system(size: 11.5))
                .foregroundStyle(Color(nsColor: Palette.ink3))
                .padding(.vertical, 7)
            PanelDivider()
                .padding(.top, 4)
                .padding(.bottom, 10)
            HubQuitButton(action: quit)
        }
        .onAppear { loginItem.refresh() }
    }

    private var loginNote: String? {
        if let error = loginItem.error { return error }
        return loginItem.status == .requiresApproval ? Strings.loginItemNeedsApproval : nil
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}

private struct HubQuitButton: View {
    let action: @MainActor () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "power")
                    .font(.system(size: 11, weight: .semibold))
                Text(Strings.quit)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(Color(nsColor: Palette.ink2))
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: hovered ? Palette.rowHover : Palette.chip)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}
