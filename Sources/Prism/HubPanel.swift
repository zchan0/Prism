import AppKit
import Observation
import PrismKit
import SwiftUI

/// The panel behind Prism's own menu bar icon: one row per enabled tool, each row expandable to that tool's controls.
///
/// This is the "merged" side of the menu bar choice. It never reaches into a tool: it reads `title`, `symbolName`
/// and `summary`, and shows whatever `hubView()` the tool hands back.
@MainActor
@Observable
final class HubModel {
    var isShown = false
    var expanded: ToolID?
}

@MainActor
final class HubPanelController {
    static let width: CGFloat = 332

    private let shell: ShellSettings
    private let registrations: [ToolRegistration]
    private let model: HubModel
    private let panel: FloatingPanelController
    var onOpenSettings: (() -> Void)?

    init(shell: ShellSettings, registrations: [ToolRegistration]) {
        self.shell = shell
        self.registrations = registrations
        model = HubModel()
        panel = FloatingPanelController(
            width: Self.width,
            content: AnyView(HubView(model: model, shell: shell, registrations: registrations, actions: HubActions(
                toggleExpanded: { _ in },
                openSettings: {},
                quit: {},
                onHeight: { _ in }
            )))
        )
        rebuild()
        panel.onVisibilityChange = { [weak self] shown in
            self?.model.isShown = shown
            if !shown { self?.model.expanded = nil }
        }
    }

    var isShown: Bool { panel.isShown }

    func toggle(below button: NSStatusBarButton) {
        if isShown {
            panel.hide()
        } else {
            rebuild()
            panel.toggle(below: button)
        }
    }

    /// Opens at the pointer, for the shortcut and for a tool's "Open Prism" menu item.
    func show(at point: NSPoint) {
        rebuild()
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main else { return }
        panel.show(anchoredAt: NSRect(x: point.x, y: point.y, width: 1, height: 1), placement: .below, on: screen)
    }

    func hide() { panel.hide() }

    /// Re-reads every tool's summary while the panel is open; called from the shell's one-second tick.
    func refreshIfVisible() {
        guard isShown else { return }
        rebuild()
        panel.refresh()
    }

    func refresh() {
        if isShown { refreshIfVisible() }
    }

    /// Rebuilt on every opening: a tool's summary and its controls are read fresh, so the panel never shows a stale
    /// countdown or a byte count from a minute ago.
    private func rebuild() {
        let actions = HubActions(
            toggleExpanded: { [weak self] id in
                guard let self else { return }
                model.expanded = model.expanded == id ? nil : id
                rebuild()
            },
            openSettings: { [weak self] in
                self?.panel.hide()
                self?.onOpenSettings?()
            },
            quit: { NSApp.terminate(nil) },
            onHeight: { [weak self] height in self?.panel.setContentHeight(height) }
        )
        panel.setContent(AnyView(HubView(model: model, shell: shell, registrations: registrations, actions: actions)))
    }
}

struct HubActions {
    var toggleExpanded: @MainActor (ToolID) -> Void
    var openSettings: @MainActor () -> Void
    var quit: @MainActor () -> Void
    var onHeight: @MainActor (CGFloat) -> Void
}

struct HubView: View {
    let model: HubModel
    let shell: ShellSettings
    let registrations: [ToolRegistration]
    let actions: HubActions

    private var enabled: [ToolRegistration] {
        registrations.filter { shell.isEnabled($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if enabled.isEmpty {
                Text(Strings.noTools)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(nsColor: Palette.ink3))
                    .padding(.vertical, 10)
            }
            ForEach(enabled, id: \.id) { registration in
                row(registration)
            }
            footer
        }
        .padding(EdgeInsets(top: 10, leading: 10, bottom: 8, trailing: 10))
        .frame(width: HubPanelController.width)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { actions.onHeight($0) }
    }

    private func row(_ registration: ToolRegistration) -> some View {
        let isExpanded = model.expanded == registration.id
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                actions.toggleExpanded(registration.id)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: registration.tool.symbolName)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(nsColor: isExpanded ? Palette.sun : Palette.ink2))
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(registration.tool.title)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(Color(nsColor: Palette.ink))
                        Text(registration.tool.summary)
                            .font(.system(size: 11, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color(nsColor: Palette.ink3))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color(nsColor: Palette.ink3))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color(nsColor: Palette.card))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded, let detail = registration.tool.hubView() {
                detail
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 2) {
            Text(verbatim: Strings.appName)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(nsColor: Palette.ink3))
            Spacer(minLength: 0)
            iconButton("slider.horizontal.3", Strings.settings, action: actions.openSettings)
            iconButton("power", Strings.quit, action: actions.quit)
        }
        .padding(.top, 4)
        .padding(.horizontal, 4)
    }

    private func iconButton(_ symbol: String, _ title: String, action: @escaping @MainActor () -> Void) -> some View {
        HubIconButton(symbol: symbol, title: title, action: action)
    }
}

private struct HubIconButton: View {
    let symbol: String
    let title: String
    let action: @MainActor () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12))
                .foregroundStyle(Color(nsColor: hovered ? Palette.ink : Palette.ink2))
                .frame(width: 24, height: 22)
                .background(RoundedRectangle(cornerRadius: 6).fill(hovered ? Color(nsColor: Palette.rowHover) : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .onHover { hovered = $0 }
    }
}
