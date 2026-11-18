import AppKit
import PrismKit
import SwiftUI

/// The quick panel, and the top of the tool's tab in the hub: how many apps there are, and the way into the window.
struct PortkeyPanelView: View {
    let tool: PortkeyTool

    var body: some View {
        PanelRow(PortkeyStrings.appsAndShortcuts, note: PortkeyStrings.appCount(tool.apps.count)) {
            PortkeyPanelButton(title: PortkeyStrings.edit) {
                tool.openWindow()
            }
        }
    }
}

private struct PortkeyPanelButton: View {
    let title: String
    let action: @MainActor () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color(nsColor: Palette.chipInk))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(height: 22)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: hovered ? Palette.rowHover : Palette.chip)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .onHover { hovered = $0 }
    }
}

private enum Metrics {
    static let windowWidth: CGFloat = 460
    static let tileSize: CGFloat = 40
    static let tileRadius: CGFloat = 10
    static let plusSize: CGFloat = 26
    static let listInset: CGFloat = 10
    static let listVertical: CGFloat = 6
    static let visibleRows = 8
    static let rowHeight: CGFloat = 44
    static let rowPadding: CGFloat = 10
    static let iconSize: CGFloat = 28
    static let iconGap: CGFloat = 12
    static let removeSlot: CGFloat = 22
    static let removeGap: CGFloat = 8
    static let keyHeight: CGFloat = 22
    static let keyRadius: CGFloat = 5
    static let keyGap: CGFloat = 3
}

/// The window's own colors, which no other part of Prism draws.
private enum PortkeyPalette {
    static let keyFill = dynamic(light: NSColor(white: 0, alpha: 0.035), dark: NSColor(white: 1, alpha: 0.075))
    static let keyBorder = dynamic(light: NSColor(white: 0, alpha: 0.15), dark: NSColor(white: 1, alpha: 0.17))
    static let dash = dynamic(light: NSColor(white: 0, alpha: 0.26), dark: NSColor(white: 1, alpha: 0.30))

    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }
}

/// The Portkey window: what a shortcut does, every app with its shortcut, and the way to add more.
struct PortkeyWindowView: View {
    let tool: PortkeyTool
    let recorder: ShortcutRecorder

    var body: some View {
        VStack(spacing: 0) {
            PortkeyHeader(tool: tool)
                .padding(.top, 36)
                .padding(.leading, 20)
                .padding(.trailing, 18)
                .padding(.bottom, 14)
            Rectangle()
                .fill(Color(nsColor: Palette.hair))
                .frame(height: 0.5)
            if tool.apps.isEmpty {
                Text(PortkeyStrings.noAppsYet)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color(nsColor: Palette.ink2))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 44)
            } else {
                PortkeyAppList(tool: tool, recorder: recorder)
            }
        }
        .frame(width: Metrics.windowWidth)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct PortkeyHeader: View {
    let tool: PortkeyTool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tool.symbolName)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: Metrics.tileSize, height: Metrics.tileSize)
                .background(
                    RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
                        .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.12))
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: tool.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(nsColor: Palette.ink))
                Text(PortkeyStrings.howItWorks)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color(nsColor: Palette.ink2))
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            PortkeyAddMenu(tool: tool)
        }
    }
}

/// Eight rows show at once; a longer list scrolls, and the window stops growing. Up to eight rows the list is as tall
/// as its rows, a refusal under one included, so it never scrolls.
private struct PortkeyAppList: View {
    let tool: PortkeyTool
    let recorder: ShortcutRecorder
    @State private var hoveredID: UUID?

    private static let maxHeight = CGFloat(Metrics.visibleRows) * Metrics.rowHeight + 2 * Metrics.listVertical

    var body: some View {
        if tool.apps.count > Metrics.visibleRows {
            ScrollView { rows }
                .frame(height: Self.maxHeight)
        } else {
            rows
        }
    }

    private var rows: some View {
        let apps = tool.apps
        return VStack(spacing: 0) {
            ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                PortkeyAppRow(tool: tool, recorder: recorder, app: app, isHovered: hoveredID == app.id)
                    .onHover { hovering in
                        if hovering {
                            hoveredID = app.id
                        } else if hoveredID == app.id {
                            hoveredID = nil
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if index < apps.count - 1, !touchesHover(apps[index], apps[index + 1]) {
                            separator
                        }
                    }
            }
        }
        .padding(.horizontal, Metrics.listInset)
        .padding(.vertical, Metrics.listVertical)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color(nsColor: Palette.hair))
            .frame(height: 0.5)
            .padding(.leading, Metrics.rowPadding + Metrics.iconSize + Metrics.iconGap)
            .padding(.trailing, Metrics.rowPadding)
    }

    // A hovered row's tint takes the place of the lines next to it, as in system lists.
    private func touchesHover(_ above: PortkeyApp, _ below: PortkeyApp) -> Bool {
        hoveredID == above.id || hoveredID == below.id
    }
}

private struct PortkeyAppRow: View {
    let tool: PortkeyTool
    let recorder: ShortcutRecorder
    let app: PortkeyApp
    let isHovered: Bool

    var body: some View {
        let name = tool.displayName(of: app)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Image(nsImage: tool.icon(of: app))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: Metrics.iconSize, height: Metrics.iconSize)
                Text(name)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(nsColor: Palette.ink))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, Metrics.iconGap)
                Spacer(minLength: 12)
                ShortcutButton(
                    appName: name,
                    shortcut: app.shortcut,
                    isRecording: recorder.recordingAppID == app.id,
                    start: { recorder.start(for: app.id) }
                )
                // Hidden rather than left out, so the row does not shift on hover and VoiceOver still finds it. A
                // transparent button would drop out of the accessibility tree, so only its image is.
                Button(action: remove) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.tertiary)
                        .opacity(isHovered ? 1 : 0)
                        .frame(width: Metrics.removeSlot, height: Metrics.removeSlot)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, Metrics.removeGap)
                .help(PortkeyStrings.remove(name))
                .accessibilityLabel(PortkeyStrings.remove(name))
            }
            .frame(height: Metrics.rowHeight)
            if let message {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(nsColor: .systemRed))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, Metrics.iconSize + Metrics.iconGap)
                    .padding(.top, -5)
                    .padding(.bottom, 10)
            }
        }
        .padding(.horizontal, Metrics.rowPadding)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovered ? Color(nsColor: Palette.rowHover) : .clear)
        )
        .contentShape(Rectangle())
        .contextMenu {
            if app.shortcut != nil {
                Button(PortkeyStrings.clearShortcut) {
                    recorder.clear(app.id)
                }
            }
            Button(PortkeyStrings.remove(name), action: remove)
        }
    }

    private func remove() {
        recorder.stop()
        tool.remove(app.id)
    }

    private var message: String? {
        if let notice = recorder.notice, notice.appID == app.id {
            switch notice.refusal {
            case .usedBy(let owner): return PortkeyStrings.usedBy(notice.shortcut.text, tool.displayName(of: owner))
            case .needsModifier: return PortkeyStrings.needsModifier
            case .refusedBySystem: return PortkeyStrings.couldNotSetUp
            }
        }
        return tool.failedAppIDs.contains(app.id) ? PortkeyStrings.couldNotSetUp : nil
    }
}

/// The app's keys, one keycap each. A click starts recording; the field then waits for the combination.
private struct ShortcutButton: View {
    let appName: String
    let shortcut: Shortcut?
    let isRecording: Bool
    let start: @MainActor () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: start) {
            label.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel(appName)
        .accessibilityValue(value)
    }

    @ViewBuilder private var label: some View {
        if isRecording {
            Text(prompt)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(height: Metrics.keyHeight)
                .background(Capsule().fill(Color.accentColor.opacity(colorScheme == .dark ? 0.16 : 0.08)))
                .overlay(Capsule().strokeBorder(Color.accentColor, lineWidth: 1.5))
        } else if let shortcut {
            HStack(spacing: Metrics.keyGap) {
                ForEach(Array(shortcut.keys.enumerated()), id: \.offset) { _, key in
                    Keycap(key: key)
                }
            }
        } else {
            Text(PortkeyStrings.recordShortcut)
                .font(.system(size: 11.5))
                .foregroundStyle(Color(nsColor: Palette.ink2))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(height: Metrics.keyHeight)
                .overlay(Capsule().strokeBorder(PortkeyPalette.dash, style: StrokeStyle(lineWidth: 1, dash: [3, 2.5])))
        }
    }

    private var prompt: String {
        shortcut == nil ? PortkeyStrings.typeShortcut : PortkeyStrings.typeShortcutOrClear
    }

    private var value: String {
        if isRecording { return prompt }
        return shortcut?.text ?? PortkeyStrings.recordShortcut
    }
}

private struct Keycap: View {
    let key: String

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.keyRadius, style: .continuous)
        Text(verbatim: key)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color(nsColor: Palette.ink))
            .padding(.horizontal, 6)
            .frame(minWidth: Metrics.keyHeight, minHeight: Metrics.keyHeight, maxHeight: Metrics.keyHeight)
            .background(shape.fill(PortkeyPalette.keyFill))
            .overlay(shape.strokeBorder(PortkeyPalette.keyBorder, lineWidth: 0.5))
    }
}

private struct PortkeyAddMenu: View {
    let tool: PortkeyTool

    var body: some View {
        let open = tool.openCandidates
        let dock = tool.dockCandidates(excluding: open)
        Menu {
            if !open.isEmpty {
                Section(PortkeyStrings.openApps) {
                    ForEach(open) { candidate in
                        item(candidate)
                    }
                }
            }
            if !dock.isEmpty {
                Section(PortkeyStrings.dockApps) {
                    ForEach(dock) { candidate in
                        item(candidate)
                    }
                }
            }
            Divider()
            Button(PortkeyStrings.otherApp) {
                tool.chooseApps()
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Color(nsColor: Palette.chipInk))
                .frame(width: Metrics.plusSize, height: Metrics.plusSize)
                .background(Circle().fill(Color(nsColor: Palette.chip)))
                .contentShape(Circle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(PortkeyStrings.addApp)
        .accessibilityLabel(PortkeyStrings.addApp)
    }

    private func item(_ candidate: AppCandidate) -> some View {
        Button {
            tool.add(candidate)
        } label: {
            Label {
                Text(candidate.name)
            } icon: {
                Image(nsImage: tool.menuIcon(atPath: candidate.path))
            }
            .labelStyle(.titleAndIcon)
        }
    }
}
