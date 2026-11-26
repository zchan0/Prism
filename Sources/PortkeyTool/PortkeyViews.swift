import AppKit
import PrismKit
import SwiftUI

private enum Metrics {
    static let panelRowHeight: CGFloat = 40
    static let visibleRows = 8
}

/// The body of the panel: every app with its shortcut. A click on an app does what its shortcut does, then closes
/// the panel.
struct PortkeyPanelView: View {
    let tool: PortkeyTool
    @Environment(\.toolPanel) private var panel

    var body: some View {
        let apps = tool.apps
        if apps.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                PanelNote(PortkeyStrings.noAppsYet)
                    .padding(.top, 4)
                PanelWideButton(Strings.addApp, symbol: "plus") {
                    panel.openSettings()
                }
            }
        } else {
            PanelCard(role: .list) {
                let rows = VStack(spacing: 0) {
                    ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                        PortkeyPanelRow(tool: tool, app: app, isFirst: index == 0) {
                            tool.switchTo(app)
                            panel.close()
                        }
                    }
                }
                if apps.count > Metrics.visibleRows {
                    ScrollView { rows }
                        .frame(height: CGFloat(Metrics.visibleRows) * Metrics.panelRowHeight)
                } else {
                    rows
                }
            }
        }
    }
}

private struct PortkeyPanelRow: View {
    let tool: PortkeyTool
    let app: PortkeyApp
    let isFirst: Bool
    let action: @MainActor () -> Void
    @State private var hovered = false

    var body: some View {
        let name = tool.displayName(of: app)
        Button(action: action) {
            HStack(spacing: 10) {
                AppIconView(image: tool.icon(of: app), size: 24)
                Text(name)
                    .font(PanelFont.title)
                    .panelInk(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                if let shortcut = app.shortcut {
                    ShortcutKeys(shortcut)
                } else {
                    Text(PortkeyStrings.noShortcut)
                        .font(PanelFont.note)
                        .panelInk(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: Metrics.panelRowHeight)
            .background(hovered ? Color(nsColor: Palette.hover) : .clear)
            .overlay(alignment: .top) {
                if !isFirst { PanelDivider.inCard }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityLabel(PortkeyStrings.goTo(name))
        .accessibilityValue(app.shortcut?.text ?? PortkeyStrings.noShortcut)
    }
}

/// The Apps card on Portkey's page in the Prism window: every app with its shortcut field, and the way to add more.
struct PortkeyAppsView: View {
    let tool: PortkeyTool
    let recorder: AppShortcutRecorder

    var body: some View {
        let apps = tool.apps
        PanelSection(PortkeyStrings.apps, note: apps.isEmpty ? PortkeyStrings.noAppsYet : PortkeyStrings.editHint) {
            ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                if index > 0 {
                    PanelDivider.inCard
                }
                PortkeyAppRow(tool: tool, recorder: recorder, app: app)
            }
            if !apps.isEmpty {
                PanelDivider.inCard
            }
            AppAddMenu(catalog: tool.catalog, isListed: tool.isListed) { candidate in
                tool.add(candidate)
            }
        }
    }
}

private struct PortkeyAppRow: View {
    let tool: PortkeyTool
    let recorder: AppShortcutRecorder
    let app: PortkeyApp

    var body: some View {
        let name = tool.displayName(of: app)
        AppListRow(name: name, icon: tool.icon(of: app), message: message, remove: remove) {
            ShortcutButton(
                name: name,
                shortcut: app.shortcut,
                isRecording: recorder.recordingSlot == app.id,
                start: { recorder.start(for: app.id) }
            )
        } menuItems: {
            if app.shortcut != nil {
                Button(Strings.clearShortcut) {
                    recorder.clear(app.id)
                }
            }
        }
    }

    private func remove() {
        recorder.stop()
        tool.remove(app.id)
    }

    private var message: String? {
        if let notice = recorder.notice, notice.slot == app.id {
            switch notice.refusal {
            case .usedBy(let owner): return PortkeyStrings.usedBy(notice.shortcut.text, tool.displayName(of: owner))
            case .needsModifier: return Strings.shortcutNeedsModifier
            case .refusedBySystem: return Strings.shortcutCouldNotBeSetUp
            }
        }
        return tool.failedAppIDs.contains(app.id) ? Strings.shortcutCouldNotBeSetUp : nil
    }
}
